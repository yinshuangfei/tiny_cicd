# Repository Guidelines

## Project Structure & Module Organization
This repository is a small Bash-based local CI wrapper around `tiny_os`. Keep source changes in `scripts/` and configuration changes in `config.env`. The main entry points are `scripts/ci.sh` for one-shot runs, `scripts/watch.sh` for polling the remote branch, and `scripts/common.sh` for shared defaults and helper functions. Treat `build/`, `logs/`, and `.ci-state/` as generated paths: `build/` is a disposable checkout of the target repo, `logs/` stores run output, and `.ci-state/` tracks the last processed commit.

## Build, Test, and Development Commands
Use the scripts directly from the repo root:

- `bash scripts/ci.sh`: clone or refresh `build/`, compile, and run the target OS checks.
- `bash scripts/ci.sh --no-pull`: rerun compile and test steps against the existing `build/` checkout.
- `bash scripts/watch.sh`: poll the configured branch and trigger CI on each new remote commit.
- `ARCH=riscv bash scripts/ci.sh`: override `config.env` for a RISC-V smoke run.
- `bash -n scripts/*.sh`: quick syntax validation before committing.

## Coding Style & Naming Conventions
Write POSIX-friendly Bash, but follow the existing stricter pattern: `#!/usr/bin/env bash`, `set -euo pipefail` where practical, quoted variables, and small helper functions. Use uppercase names for exported configuration such as `REPO_URL` and `QEMU_TIMEOUT`; use lowercase for local variables and function names such as `remote_sha` and `short_sha`. Keep comments brief and only where control flow is not obvious.

## Testing Guidelines
There is no separate unit-test suite in this repo; validation is script-driven. For changes to orchestration logic, run `bash -n scripts/*.sh` and at least one `bash scripts/ci.sh --no-pull` cycle. If you touch polling, state handling, or configuration loading, also run `bash scripts/watch.sh` long enough to confirm startup and change detection behavior. Include the relevant log path from `logs/ci-<sha>.log` when reporting results.

## Commit & Pull Request Guidelines
Git history is currently sparse and uses short imperative subjects (`Initial commit`, `add code`). Keep commit titles concise, imperative, and scoped to one change, for example `watch: handle sync retry`. Pull requests should describe the user-visible behavior change, list the commands you ran, note any `config.env` or environment assumptions, and include representative log excerpts when CI behavior changes.
