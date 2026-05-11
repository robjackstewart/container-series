package main

# Deny an image when any reported vulnerability is marked as CRITICAL.
deny[msg] {
  vuln := input.vulnerabilities[_]
  upper(vuln.severity) == "CRITICAL"
  msg := sprintf("critical vulnerability detected: %s", [vuln.id])
}

# Require the container image config to specify a non-root user.
deny[msg] {
  not input.config.user
  msg := "container image must set a non-root user"
}

# Treat common root-equivalent values as a policy violation.
deny[msg] {
  lower(sprintf("%v", [input.config.user])) == "root"
  msg := "container image must not run as root"
}

deny[msg] {
  sprintf("%v", [input.config.user]) == "0"
  msg := "container image must not use UID 0"
}
