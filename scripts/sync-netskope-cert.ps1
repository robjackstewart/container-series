<#
.SYNOPSIS
    Copies the corporate Netskope CA certificate into every talk's certs/ folder.

.DESCRIPTION
    Each talk in this series trusts an optional corporate CA during its build via a BuildKit
    secret (--secret id=netskope_cert,src=certs/netskope.crt). That means the same certificate
    has to exist in ~19 certs/ folders. This script puts it in all of them in one go.

    The source certificate is resolved in this order:

      1. -Source <path>, if you pass one explicitly.
      2. The Netskope agent's own copy at %ProgramData%\netskope\stagent\data\nscacert.pem.
         Preferred default: the agent keeps this current, so a CA rotation is picked up for
         free the next time you run this script.
      3. Export from the Windows certificate store (any root CA whose subject matches
         -StoreMatch, default 'netskope').

    Certificates are written as LF-terminated, BOM-free PEM. CRLF in a PEM is tolerated by
    OpenSSL but not worth the risk given these files cross into Linux containers.

    Nothing is committed: .gitignore has '**/certs/*' with an exception only for .gitkeep.

.PARAMETER Source
    Path to a PEM certificate to distribute. Skips auto-discovery.

.PARAMETER Name
    Filename to write into each certs/ folder. Defaults to netskope.crt, which is what every
    Dockerfile, compose file, and README in this repo references. Change it only if you also
    change those.

.PARAMETER StoreMatch
    Subject substring used when falling back to a Windows certificate store export.

.PARAMETER Force
    Overwrite an existing file whose contents differ. Without this, differing files are left
    alone and reported, so a hand-placed cert is never silently clobbered.

.PARAMETER Remove
    Delete $Name from every certs/ folder instead of copying. Use when moving off the
    corporate network, or to prove the no-cert build failure in talk-01.

.EXAMPLE
    .\scripts\sync-netskope-cert.ps1
    Auto-discover the CA and copy it into every talk.

.EXAMPLE
    .\scripts\sync-netskope-cert.ps1 -Source C:\temp\corp-ca.pem -Force
    Distribute a specific certificate, overwriting any that differ.

.EXAMPLE
    .\scripts\sync-netskope-cert.ps1 -Remove
    Strip the cert from every talk (back to the shipped, cert-free state).

.NOTES
    If your Netskope tenant re-signs with the *tenant* certificate rather than the CA
    certificate, point -Source at nstenantcert.pem in the same agent folder instead.
#>
[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Copy')]
param(
    [Parameter(ParameterSetName = 'Copy')]
    [string] $Source,

    [string] $Name = 'netskope.crt',

    [Parameter(ParameterSetName = 'Copy')]
    [string] $StoreMatch = 'netskope',

    [Parameter(ParameterSetName = 'Copy')]
    [switch] $Force,

    [Parameter(ParameterSetName = 'Remove')]
    [switch] $Remove
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Extract the SHA1 thumbprints of every certificate in a PEM blob, so two files can be compared
# by what they actually contain. A byte comparison would flag a hand-placed cert as DIFFERS
# purely because of base64 line wrapping or line endings, which is a false alarm.
function Get-PemThumbprint {
    param([string] $Text)
    $result = [Collections.Generic.List[string]]::new()
    foreach ($m in [regex]::Matches($Text, '(?s)-----BEGIN CERTIFICATE-----(.*?)-----END CERTIFICATE-----')) {
        try {
            $b64 = ($m.Groups[1].Value -split '\r?\n' | Where-Object { $_.Trim() }) -join ''
            $cert = [Security.Cryptography.X509Certificates.X509Certificate2]::new([Convert]::FromBase64String($b64))
            $result.Add($cert.Thumbprint)
        } catch {
            return $null   # unparseable: caller falls back to text comparison
        }
    }
    if ($result.Count -eq 0) { return $null }
    return ($result | Sort-Object) -join ','
}

# --- Locate the repository root ----------------------------------------------------------
# Prefer git so the script works from any working directory; fall back to the script's parent.
$repoRoot = $null
try {
    $gitRoot = & git -C $PSScriptRoot rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -eq 0 -and $gitRoot) { $repoRoot = (Resolve-Path $gitRoot).Path }
} catch { }
if (-not $repoRoot) { $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }

Write-Verbose "Repository root: $repoRoot"

# --- Find every certs/ folder -----------------------------------------------------------
$certDirs = Get-ChildItem -LiteralPath $repoRoot -Directory -Recurse -Filter 'certs' -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' } |
    Sort-Object FullName

if (-not $certDirs) {
    throw "No certs/ folders found under $repoRoot. Are you running this inside the container-series repo?"
}

Write-Host "Found $($certDirs.Count) certs/ folder(s) under $repoRoot" -ForegroundColor Cyan

# --- Removal mode -----------------------------------------------------------------------
if ($Remove) {
    $removed = 0
    foreach ($dir in $certDirs) {
        $target = Join-Path $dir.FullName $Name
        if (Test-Path -LiteralPath $target) {
            if ($PSCmdlet.ShouldProcess($target, 'Remove certificate')) {
                Remove-Item -LiteralPath $target -Force
            }
            $removed++
            $relative = $dir.FullName.Substring($repoRoot.Length).TrimStart('\', '/')
            Write-Host ("  removed   {0}" -f $relative) -ForegroundColor Yellow
        }
    }
    Write-Host ""
    Write-Host "Removed $Name from $removed folder(s)." -ForegroundColor Green
    return
}

# --- Resolve the source certificate -----------------------------------------------------
$pem = $null
$origin = $null

if ($Source) {
    if (-not (Test-Path -LiteralPath $Source)) { throw "Source certificate not found: $Source" }
    $pem = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $Source).Path)
    $origin = "explicit path: $Source"
}

if (-not $pem) {
    # The Netskope agent's own copy. Checked case-insensitively via the filesystem anyway,
    # but both casings are listed because different agent versions differ.
    $agentPaths = @(
        (Join-Path $env:ProgramData 'netskope\stagent\data\nscacert.pem'),
        (Join-Path $env:ProgramData 'Netskope\STAgent\data\nscacert.pem'),
        (Join-Path $env:ProgramData 'netskope\stagent\download\nscacert.pem')
    )
    foreach ($p in $agentPaths) {
        if (Test-Path -LiteralPath $p) {
            $pem = [IO.File]::ReadAllText($p)
            $origin = "Netskope agent: $p"
            break
        }
    }
}

if (-not $pem) {
    # Last resort: export from the Windows root store. Dedupe by thumbprint, since the same
    # CA is typically present in both LocalMachine and CurrentUser.
    $store = @(Get-ChildItem Cert:\LocalMachine\Root, Cert:\CurrentUser\Root -ErrorAction SilentlyContinue |
        Where-Object { $_.Subject -match $StoreMatch } |
        Sort-Object Thumbprint -Unique)

    if ($store.Count -eq 0) {
        throw @"
Could not find a corporate CA to distribute.

Tried:
  - -Source (not supplied)
  - Netskope agent copy under `$env:ProgramData\netskope\stagent\
  - Windows root store, subject matching '$StoreMatch'

If you are not behind a TLS-intercepting proxy you do not need this script at all: every
Dockerfile treats a missing certificate as a no-op. Otherwise pass -Source explicitly.
"@
    }
    if ($store.Count -gt 1) {
        Write-Warning "Multiple root CAs match '$StoreMatch'; using the first. Pass -Source to be explicit:"
        $store | ForEach-Object { Write-Warning ("  {0}  {1}" -f $_.Thumbprint, $_.Subject) }
    }

    $cert = $store[0]
    $b64 = [Convert]::ToBase64String($cert.RawData, 'InsertLineBreaks')
    $pem = "-----BEGIN CERTIFICATE-----`n" + (($b64 -replace "`r`n", "`n").TrimEnd()) + "`n-----END CERTIFICATE-----`n"
    $origin = "Windows certificate store: $($cert.Subject)"
}

# Normalise to LF, no BOM, single trailing newline.
$pem = ($pem -replace "`r`n", "`n").TrimEnd() + "`n"

if ($pem -notmatch '-----BEGIN CERTIFICATE-----') {
    throw "Resolved source does not look like a PEM certificate (no BEGIN CERTIFICATE block). Origin: $origin"
}

# --- Report what we are about to distribute ---------------------------------------------
$blockCount = ([regex]::Matches($pem, '-----BEGIN CERTIFICATE-----')).Count
Write-Host "Source: $origin" -ForegroundColor Cyan

try {
    # Parse the first certificate purely to show subject/expiry — a cert that has already
    # expired produces exactly the same NU1301 as having no cert at all, so it is worth
    # surfacing before it costs someone a confusing debugging session.
    $first = [regex]::Match($pem, '(?s)-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----').Value
    $der = [Convert]::FromBase64String((($first -split "`n" | Where-Object { $_ -notmatch '-----' }) -join ''))
    $parsed = [Security.Cryptography.X509Certificates.X509Certificate2]::new($der)

    Write-Host ("Subject: {0}" -f $parsed.Subject) -ForegroundColor Cyan
    Write-Host ("SHA1:    {0}" -f $parsed.Thumbprint) -ForegroundColor Cyan
    Write-Host ("Expires: {0:yyyy-MM-dd}" -f $parsed.NotAfter) -ForegroundColor Cyan
    if ($blockCount -gt 1) {
        Write-Warning "$blockCount certificates in this bundle. update-ca-certificates expects one cert per .crt file; a multi-cert bundle may not be trusted as you expect."
    }
    if ($parsed.NotAfter -lt (Get-Date)) {
        Write-Warning "This certificate EXPIRED on $($parsed.NotAfter.ToString('yyyy-MM-dd')). Builds will still fail with NU1301."
    } elseif ($parsed.NotAfter -lt (Get-Date).AddDays(30)) {
        Write-Warning "This certificate expires in $([int]($parsed.NotAfter - (Get-Date)).TotalDays) day(s)."
    }
} catch {
    Write-Warning "Could not parse the certificate for reporting: $($_.Exception.Message)"
}

Write-Host ""

# --- Distribute -------------------------------------------------------------------------
$utf8NoBom = New-Object Text.UTF8Encoding $false
$added = 0; $updated = 0; $unchanged = 0; $skipped = 0; $reformatted = 0
$sourceThumbprint = Get-PemThumbprint -Text $pem

foreach ($dir in $certDirs) {
    $target = Join-Path $dir.FullName $Name
    $relative = $dir.FullName.Substring($repoRoot.Length).TrimStart('\', '/')
    $existing = if (Test-Path -LiteralPath $target) { [IO.File]::ReadAllText($target) } else { $null }

    if ($null -ne $existing) {
        if ((($existing -replace "`r`n", "`n").TrimEnd() + "`n") -eq $pem) {
            $unchanged++
            Write-Host ("  ok        {0}" -f $relative) -ForegroundColor DarkGray
            continue
        }

        # Same certificate, different formatting (line wrapping or CRLF). Normalise it rather
        # than reporting a conflict that isn't one.
        $existingThumbprint = Get-PemThumbprint -Text $existing
        if ($sourceThumbprint -and $existingThumbprint -eq $sourceThumbprint) {
            if ($PSCmdlet.ShouldProcess($target, 'Normalise formatting (same certificate)')) {
                [IO.File]::WriteAllText($target, $pem, $utf8NoBom)
            }
            $reformatted++
            Write-Host ("  ok        {0}  (same cert, formatting normalised)" -f $relative) -ForegroundColor DarkGray
            continue
        }
        # Genuinely a different certificate. Never clobber it without being told to.
        if (-not $Force) {
            $skipped++
            $detail = if ($existingThumbprint) { "existing SHA1 $existingThumbprint" } else { 'existing file is not parseable as PEM' }
            Write-Host ("  DIFFERS   {0}  ({1}; use -Force to overwrite)" -f $relative, $detail) -ForegroundColor Yellow
            continue
        }
        if ($PSCmdlet.ShouldProcess($target, 'Overwrite certificate')) {
            [IO.File]::WriteAllText($target, $pem, $utf8NoBom)
        }
        $updated++
        Write-Host ("  updated   {0}" -f $relative) -ForegroundColor Green
        continue
    }

    if ($PSCmdlet.ShouldProcess($target, 'Write certificate')) {
        [IO.File]::WriteAllText($target, $pem, $utf8NoBom)
    }
    $added++
    Write-Host ("  added     {0}" -f $relative) -ForegroundColor Green
}

Write-Host ""
Write-Host ("$Name -> added $added, updated $updated, already current $($unchanged + $reformatted), skipped $skipped") -ForegroundColor Green

if ($skipped -gt 0) {
    Write-Host "Re-run with -Force to replace the files marked DIFFERS (a different certificate is already there)." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Build with it:" -ForegroundColor Cyan
Write-Host "  docker build --secret id=netskope_cert,src=.\certs\$Name -t myapp ." -ForegroundColor Gray
