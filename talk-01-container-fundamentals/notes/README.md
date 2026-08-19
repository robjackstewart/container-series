# Speaker Guide — Talk 01: Container Fundamentals

> The teaching narrative. Keep this on your private screen or printed; share the deck and the terminal.
> For the exact commands, use [`../RUNSHEET.md`](../RUNSHEET.md). For the visuals, present [`../slides/talk-01.html`](../slides/talk-01.html).

## How this guide lines up with the deck

Every section below names the slides it covers. The deck shows the slide number bottom-right and the
section name top-right, so at any point you can glance at the screen and find your place here.
Press <kbd>O</kbd> in the deck for a clickable index of all 36 slides.

| Deck slides | Section in this guide | Live demo |
| --- | --- | --- |
| 1–2 | [Opening](#opening--slides-12) | — |
| 3–7 | [§1 Containers are packaged processes](#1-containers-are-packaged-processes-not-lightweight-vms--slides-37) | **Demo 1** on slide 7 |
| 8–10 | [§2 Docker architecture and the build context](#2-docker-architecture-and-the-build-context--slides-810) | — |
| 11–12 | [§3 The first Dockerfile](#3-the-first-dockerfile-readable-useful-intentionally-imperfect--slides-1112) | — |
| 13–18 | [§3a The build has its own trust store](#3a-the-build-has-its-own-trust-store-the-deliberate-failure--slides-1318) | **Demo 2** on slide 16 |
| 19–23 | [§4 Layers, cache reuse, and ordering](#4-layers-cache-reuse-and-why-ordering-matters--slides-1923) | **Demo 3** on slide 23 |
| 24–25 | [§5 Build-time values versus runtime configuration](#5-build-time-values-versus-runtime-configuration--slides-2425) | — |
| 26–29 | [§6 Multi-stage builds](#6-multi-stage-builds-the-default-production-shape--slides-2629) | **Demo 4** on slide 29 |
| 30 | [§7 BuildKit cache mounts](#7-buildkit-cache-mounts-and-developer-feedback--slide-30) | — |
| 31 | [§8 Ports, logs, and operational basics](#8-ports-logs-and-operational-basics--slide-31) | — |
| 32–33 | [§9 Bonus corner](#9-bonus-corner-dive-and-scratch--slides-3233) | **Demo 5** on slide 33 |
| 34–36 | [Closing](#closing--slides-3436) | — |

## The arc
Start with the mental model: a container is not a tiny virtual machine, it is a process with isolation and packaged dependencies. Then build a deliberately straightforward image so the mechanics are visible, walk into a real failure that proves where a build step actually runs, inspect the layers, and finish by reshaping the same app into a production-friendly multi-stage image. The big idea is that container quality is mostly about boundaries: what enters the build context, what becomes a layer, what stays in the final image, and what is supplied at runtime.

---

## Opening — slides 1–2

- Slide 1 states the thesis in one sentence and gets it out of the way early: **a container is a process with its dependencies packaged alongside it**. Everything else in the hour follows from that.
- Slide 2 is the route map. It exists so the room knows §3a is a deliberate detour rather than you losing your way, and so they can see the five demo points coming.
- Worth saying out loud: the four boundaries on slide 2 (context → layer → final image → runtime) are the spine of the talk. If someone only remembers that framing, the hour was worth it.

---

## §1) Containers are packaged processes, not lightweight VMs — slides 3–7

**Slide 4 — the diagram does the arguing.** The two stacks differ by exactly one row.

- Land the distinction clearly: a VM virtualises hardware and carries a guest operating system; a Linux container shares the host kernel and isolates processes with kernel primitives.
- The dashed empty region on the right of slide 4 is the whole size and start-up difference, drawn as an absence. Point at it.
- Emphasise the trade-off: containers start quickly and distribute efficiently, but they do not have the same isolation boundary as a full virtual machine. Say plainly that a kernel-level escape is a shared risk, and that a VM is still the right tool for untrusted code or strict regulatory separation.

**Slide 5 — isolation is not magic.**

- Namespaces give the process its own view of things such as process IDs, networking, mounts, host names, and users. cgroups constrain resources such as CPU and memory.
- The useful framing on the slide: namespaces limit what a process can **see**; cgroups limit what it can **consume**. Take both away and you are left with a plain process, which is what it was all along.
- The `exit code 137` note is worth a sentence — people meet OOM kills long before they understand cgroups.

**Slide 6 — image versus container.**

> Expert aside: an image is inert data; a container is a running process created from that data plus runtime configuration. That distinction explains why rebuilding an image and restarting a container are different operational actions.

- The slide spells out the operational consequence in two lines: changed the Dockerfile → rebuild; changed an env var → recreate the container, no rebuild. This is the single most useful thing to hand a team new to containers.
- Also point out that the read-only layers are shared on disk, so three containers from one image cost roughly one image.

**Slide 7 — Demo 1.** Run the API with plain `dotnet run` before Docker enters the conversation.

- Containerisation should not hide app basics. If it does not run here, containerising it only adds a second thing to debug.
- Note `version: dev` in the `/info` response. That value is a thread you will pull again on slides 25 and 29.

---

## §2) Docker architecture and the build context — slides 8–10

**Slide 9 — three moving parts, one of which is not on your machine.**

- Introduce the Docker client, Docker daemon, image registry, image, and container as separate moving parts.
- The clay panel at the bottom of slide 9 is the setup for §3a, so do not rush it: **the daemon cannot see your files, your environment variables, your VPN, or your certificate trust store.** Anything a build step needs must be handed to it deliberately.
- On Windows and macOS the daemon is a separate Linux VM entirely, which makes "it is not your shell" concrete rather than pedantic.

**Slide 10 — the build context.**

- The build context is the set of files sent to the builder. It is not automatically "the repo"; it is whatever the chosen context path includes after `.dockerignore` is applied. That trailing dot in `docker build .` is a parameter, not punctuation.
- The measured number on the slide is from this repo: `src/` is **3.0 MB on disk** but produces a **20.5 kB layer**, because `**/bin/` and `**/obj/` are in `.dockerignore`.
- Use this to motivate context hygiene early. A noisy context slows builds and can accidentally make local artefacts available to Dockerfile instructions.
- Good moment for the first discussion prompt: what would enter *your* build context if `.dockerignore` vanished?

> Expert aside: OCI image layers are tar archives addressed by cryptographic digest. Registries and runtimes can deduplicate them because the digest represents the layer content, not the local file name or tag you happened to use.

---

## §3) The first Dockerfile: readable, useful, intentionally imperfect — slides 11–12

- Walk through the single-stage Dockerfile as the first principles version: choose a base image, set a working directory, copy source, restore, publish, document the port, and define the process.
- Use it to explain `FROM`, `WORKDIR`, `COPY`, `RUN`, `EXPOSE`, `ENV`, and `ENTRYPOINT` without overloading the room. The right-hand column of slide 12 has one line per instruction.
- Be honest that it works but is not how we would ship most production services. The SDK, build tooling, and source tree remain in the final image — **1.27 GB** of it, measured.
- **Do not explain the `--mount=type=secret` line yet.** It is visible on the slide deliberately; let someone ask, and if nobody does, move to §3a and let the build fail first.

> Expert aside: broad copy steps such as `COPY . .` are convenient, but Docker cache keys include the copied content. A README edit or local artefact can invalidate an expensive restore layer unless the Dockerfile first copies only stable dependency descriptors.

---

## §3a) The build has its own trust store (the deliberate failure) — slides 13–18

This is a five-minute detour that lands the build context idea harder than any diagram, and it is worth running live rather than describing. **Slides 13–15 set the puzzle, slide 16 is the demo, slides 17–18 are the resolution.**

**Set it up as a puzzle (slides 13–14).**

- `dotnet restore` works perfectly in your terminal. The *same command*, against the *same project*, fails the moment it runs inside the builder. Ask the room why, and let them sit with it.
- The answer is the point of the whole section: `RUN` does not execute on the host. It executes inside a container built from the base image, with that image's filesystem — including its CA trust store. Your laptop trusts the corporate CA because IT put it there; `mcr.microsoft.com/dotnet/sdk:8.0` has never heard of your employer.
- Slide 14 draws both trust stores side by side under one identical command. The environment differs, not the command.

**Narrow it down (slide 15, demo beats 1–3).**

- Show the bare failure first. `error NU1301: Unable to load the service index for source https://api.nuget.org/v3/index.json` is deliberately unhelpful, and that ambiguity is useful teaching material: it reads like "no network", which is what sends people down the wrong debugging path.
- Then narrow it with `curl` in the same base image: `curl: (60) SSL certificate problem: self-signed certificate in certificate chain`. The connection succeeded. The certificate was rejected. Those are very different problems with the same symptom.
- Explain the mechanism plainly: a TLS-intercepting proxy terminates the connection, inspects it, and re-signs it with its own CA. From inside the container, something is presenting itself as nuget.org with a certificate signed by an unknown authority. Refusing that is TLS doing its job. **The container is right and we are the ones lying to it.**
- **Beat 3 is the one that settles it.** Run the *same* container and the *same* `curl`, but bind-mount the CA into `/usr/local/share/ca-certificates/` and run `update-ca-certificates` first. It prints `1 added, 0 removed; done.` and nuget.org answers. One variable changed, no Dockerfile touched — so the certificate is provably the missing piece rather than a plausible theory. Only then move to the build, where `--mount=type=secret` does exactly this without leaving anything behind.
- The `rehash: warning: skipping ca-certificates.crt` line in beat 3 is harmless noise from `update-ca-certificates` reading the existing bundle. Mention it only if someone asks.

**Then show the fix, and be deliberate about *which* fix (slide 17).**

- The tempting options are both bad. Disabling certificate validation trades a build problem for a security hole. `COPY netskope.crt` into the image works, but it bakes your organisation's interception CA into a layer that ships to every consumer of the image — visible in `docker history`, extractable from any pull.
- `RUN --mount=type=secret` is the right shape. The cert is mounted at `/run/secrets/netskope_cert` for the lifetime of one `RUN` instruction, added to the trust store, used, and removed — with the original bundle restored before the layer is committed. Nothing about it enters the image.
- Prove it rather than claiming it (demo beat 5). There is no `netskope.crt` in the finished image and no `/run/secrets` directory. This is a good moment to point out that "trust me, it's clean" is not an engineering standard.
- Close the loop on portability: the guard is `if [ -s /run/secrets/netskope_cert ]`, so omitting `--secret` is a complete no-op. The same Dockerfile works on the corporate network, at home, and in CI without modification — which is the actual requirement, not just "works on my machine".

**The cache-key gotcha (slide 18).** Do not skip this; it will bite someone in the room.

> Expert aside: a secret mount's *contents* are not part of the layer cache key — only the fact that a mount is declared. That is what makes the same Dockerfile cacheable across machines with different certs, but it also means a build that already has a cached restore layer will happily "succeed" without the cert. Hence `--no-cache` when demonstrating the failure. It is also the reason secret mounts cannot be used to invalidate cache on purpose.

> Second aside, if the room includes anyone who builds with non-Dockerfile tooling: Aspire, Buildpacks, `ko`, `jib`, and Nixpacks have no equivalent of `--mount=type=secret`, so they need the CA trusted at host/OS level instead. Talk 14 hits this properly.

**If you are presenting off the corporate network:** beat 1 will simply succeed. Narrate the expected output from the runsheet rather than manufacturing a failure, and keep slides 14–15 and 17–18 — the teaching stands on its own.

---

## §4) Layers, cache reuse, and why ordering matters — slides 19–23

**Slide 20 is the centrepiece of the talk.** Every Dockerfile instruction has a leader line to what it actually produces, with slab heights proportional to real measured size.

- Walk it in file order, not stack order. `FROM` fans out into ten inherited layers — one line, ≈883 MB. `WORKDIR` costs 8.19 kB because it created a directory, so it is not quite free. `COPY` is 20.5 kB. `RUN restore` is 41.8 MB of NuGet packages. `RUN publish` is 5.64 MB. Then `ENV`, `EXPOSE` and `ENTRYPOINT` all converge on the config blob at **0 B**.
- The distinction to leave behind: `FROM`, `COPY` and `RUN` add filesystem layers; `ENV`, `EXPOSE`, `ENTRYPOINT`, `USER`, `CMD`, `LABEL` and `ARG` only change the config.
- Sizes on that slide are as `docker history` reports them. `docker image ls` totals the same image at 1.27 GB — the two tools count differently, so quote whichever one is on screen rather than mixing them. If someone spots the discrepancy, that is a good catch, not a problem.

**Slide 21 — a layer is a diff, not a directory.** This slide earns its place because it explains two things at once.

- The trap: deleting a file in a later layer writes a whiteout marker. The bytes stay in the layer below, still in the image size, still extractable. `RUN wget secret && use-it && rm secret` across two separate `RUN` steps does not remove the secret. **This is the mechanical reason the CA is a secret mount rather than a `COPY`** — tie it straight back to §3a.
- The gift: layers are content-addressed, so identical layers are stored and transferred once across images, hosts and registries.

**Slide 22 — ordering.**

- `docker history` is the bridge from Dockerfile text to image reality; slide 22 is the same idea applied to *change*. One source edit, two orderings, opposite amounts of rework.
- Good Dockerfiles put stable, expensive work early and volatile source changes later. For .NET, that means restoring after the project file is copied, then copying the rest of the source before publish.
- Give them the rule in the form on the slide: **cache key = the instruction text + the content of whatever it copies + the key of the layer beneath. The first miss invalidates everything after it.**
- Explain that caching is not just about speed. It also makes builds more predictable, easier to reason about, and cheaper in CI.

**Slide 23 — Demo 3.** `docker history weatherapi:single`.

- Point at the 508 MB line. Nobody in the room wrote it.
- Then say it plainly: we are shipping a compiler, PowerShell, git and curl to production so a web API can answer three HTTP endpoints. §6 deletes all of it.
- `dive` belongs here if it is installed — same concept, but you can see inside each layer.

---

## §5) Build-time values versus runtime configuration — slides 24–25

- `ARG` is for the build. It can stamp the image or choose build-time behaviour, but it is not a reliable runtime configuration mechanism.
- `ENV` is part of the image configuration and becomes visible to the application process unless overridden when the container starts.
- Slide 25 draws all four mechanisms against one boundary: `--build-arg` enters at build; `ENV` crosses into the image; `-e` overrides at run time; `--secret` enters and leaves without ever crossing. The secret's path is the one that loops back out.
- Use `APP_VERSION` as the simple example: CI can stamp it at build time, and the container can expose it at runtime through the API. Call back to slide 7, where `/info` said `dev`.
- Say the warning on the slide out loud: **`ARG` values are visible in `docker history`.** An `ARG` is never a place for a password, a token or a key.

---

## §6) Multi-stage builds: the default production shape — slides 26–29

**Slide 27 — one arrow crosses the boundary.**

- The build stage uses the SDK because compilation needs the compiler, restore tooling, and publish tooling.
- The runtime stage uses the ASP.NET Core runtime image because the application only needs the published output and the runtime.
- `COPY --from=build` is the only channel between the stages, carrying 2.71 MB. Anything not explicitly carried across does not exist in the final image — including mistakes, caches and credentials.
- The ≈883 MB left behind is never pushed, never pulled, never scanned for CVEs, never present in production.

**Slide 28 — the measured payoff.** 1.27 GB → 324 MB for eleven extra lines.

- Highlight the security and operations wins: smaller image, fewer packages to scan, clearer responsibility, faster pulls, and a non-root user.
- The detail that lands best: of the 324 MB, **our application is 2.71 MB**. The rest is a runtime shared with every other .NET image on the host.

> Expert aside: smaller images are not automatically secure, but they reduce the inventory of things that can be vulnerable. The better question is "does the final image contain only what the process needs to run?"

**Slide 29 — Demo 4.** Build, run, override, compare.

- `version: 1.0.0` proves `--build-arg` reached the image; `-e APP_VERSION=2.0.0` proves runtime configuration wins without a rebuild.
- `docker exec … whoami` returns `app`, not root.
- `docker history weatherapi:multi` — the restore layer is simply *not there*.

---

## §7) BuildKit cache mounts and developer feedback — slide 30

- BuildKit cache mounts keep the NuGet package cache outside the final image while still speeding up repeated restores.
- This is a good example of separating build acceleration from runtime contents. The cache helps the builder; it does not become part of the deployed artefact.
- **Be straight with the room:** neither Dockerfile in this talk uses a cache mount. They were kept simple on purpose, and this is the next improvement rather than something already in the code.
- Be precise about what it buys. In the *multi-stage* build the restore layer is discarded anyway, so a cache mount buys **build speed**, not a smaller image. In the *single-stage* build it would also remove those 41.8 MB from the shipped result.
- Reinforce that modern Docker Desktop enables BuildKit by default, but the `# syntax=` line makes the advanced mount syntax explicit.

---

## §8) Ports, logs, and operational basics — slide 31

- `EXPOSE` is documentation for humans and tooling; publishing a port happens when the container is run. The slide draws the host boundary with an opening only where `-p` created one.
- `-p 5000:8080` is worth showing on the slide: the host chooses the port, the app still hears 8080. Host port and container port are independent.
- Logs should go to standard output and standard error. Containers are easier to operate when the platform can collect logs without entering the container.
- Writing to `/var/log/app.log` inside the container puts the logs in the writable layer, invisible to the platform and deleted with the container. Talk 15 builds the whole observability story on this one habit.
- `.dockerignore` was covered on slide 10; if you skipped the discussion prompt there, this is the second-best place for it.

---

## §9) Bonus corner: dive and scratch — slides 32–33

Use `dive` if the room is curious about what actually changed in each layer. It makes the "images are content-addressed filesystem changes" idea visible and helps people spot wasted space quickly.

The `scratch` example is deliberately extreme: a static Go binary copied into an empty filesystem. It is useful because it strips the model down to the minimum possible final image — **1.82 MB in a single layer**, no shell, no package manager, no libc, and no operating-system userland. The trade-off is equally important: if it fails in production, you cannot exec into a shell to poke around, and you must explicitly provide anything the binary needs, such as CA certificates for outbound TLS.

- Run the last command on slide 33 deliberately: `docker run --rm -it --entrypoint sh hello-scratch` fails with `exec: "sh": executable file not found in $PATH`. The error *is* the lesson. The trade-off stops being abstract the moment someone watches a shell fail to exist.
- Then pose the question on slide 32: which is riskier, a large image full of familiar tools, or a tiny one you cannot debug? The disagreement is the useful part. Talk 07 takes it on properly with distroless and Chainguard images.

---

## Closing — slides 34–36

**Slide 34 — discussion prompts.** Six questions, in the order they tend to produce argument:

- What files in your current projects would accidentally enter a Docker build context if `.dockerignore` were missing?
- When would a VM still be a better boundary than a container?
- Which is riskier: a large image with familiar tools inside, or a tiny image that makes live debugging harder?
- What should be decided at image build time, and what must remain runtime configuration?
- If a source edit forces dependency restore every time, what Dockerfile ordering mistake would you suspect first?
- A command works in your terminal and fails in `RUN`. What is different about the environment, and where else does that difference bite?
- Your build needs a credential or certificate to fetch dependencies. How do you supply it without it ending up in the shipped image?

**Slide 35 — key takeaways.**

- Containers package an application and its dependencies while sharing the host kernel.
- An image is inert data; a container is that image plus runtime configuration plus a running process.
- `RUN` executes inside the image, not on your machine — its network, filesystem, and CA trust store are the base image's, not yours.
- Build-time secrets belong in `--mount=type=secret`, never in a `COPY` or an `ARG`.
- Dockerfile ordering matters because images are layered and cache keys are content-sensitive.
- `ARG` is build-time input; `ENV` and run arguments shape runtime behaviour.
- `.dockerignore` is part of the security and performance story, not housekeeping.
- Multi-stage builds are the normal production pattern for compiled applications.
- Running as a non-root user is a small change with a meaningful security benefit.
- BuildKit cache mounts can improve feedback loops without bloating runtime images.

If only one sentence survives the week, make it the framing from slide 2: **container quality is about boundaries** — what enters the build context, what becomes a layer, what crosses into the final image, and what is supplied at run time.

**Slide 36 — the handover.** Talk 02 moves from image fundamentals into runtime configuration: ports, environment variables, secrets, networking, bind mounts, volumes, tmpfs, health checks and resource limits, in Python and Flask.

---

## Netskope / corporate proxy note

This talk uses Dockerfiles for all image builds. The SDK build stages trust an optional corporate CA certificate via a BuildKit secret (`--secret id=netskope_cert,src=certs/netskope.crt`) before NuGet restore runs. The cert is never written to any image layer — omit `--secret` when not behind a TLS-intercepting proxy.

Distribute the certificate with `scripts/sync-netskope-cert.ps1` from the repo root — it writes `netskope.crt` into all 19 `certs/` folders, preferring the Netskope agent's own copy so a CA rotation is picked up for free. Run it with `-Remove` if you want to rehearse the failing build off the corporate network.

Behind Netskope this is promoted from a footnote to a teaching beat — see **§3a** above and **slides 13–18**, which build without the cert on purpose to show *why* it is needed. If you are presenting off the corporate network the failing build will simply succeed; narrate the expected output from the runsheet instead of forcing a fake failure.

The final ASP.NET Core runtime image in the multi-stage example does not make outbound TLS calls during the demo, so no additional CA bundle is copied there. The `scratch` bonus image has no CA trust store at all; copy `ca-certificates.crt` from a builder only if the binary itself needs outbound TLS.
