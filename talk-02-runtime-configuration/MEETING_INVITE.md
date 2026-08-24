# Container Series – Talk 02: Runtime Configuration Deep Dive

**When:** [DATE/TIME]
**Where:** [ROOM / TEAMS LINK]

## Overview

Following on from Talk 01, this session moves from *building* a container image to *running* it properly. Using the same Flask-based demo app, we'll walk through the runtime knobs that decide how a container actually behaves in the real world: environment variables and env files, keeping secrets out of image layers with BuildKit secret mounts, networking modes, storage choices (bind mounts, volumes, tmpfs), health checks, restart policies, and resource limits. As a bonus, we'll take a quick look at Podman as a daemonless alternative to Docker.

## You should come along if

- You've ever wondered why an app behaves differently in a container than it did in the build/test environment
- You want to stop hardcoding config and secrets into Dockerfiles and images
- You're responsible for running containers in production and want a better handle on health checks, restarts, and resource limits
- You're following the Container Series and want the next instalment (no prior container experience assumed beyond Talk 01)
- You're just curious about Podman as a Docker alternative

## Catch up on last week

Missed Talk 01 (Container Fundamentals — Building Your First Image)? [LINK TO TALK 01 RECORDING/MATERIALS]
