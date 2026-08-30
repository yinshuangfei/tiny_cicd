# tiny_cicd

A minimal CI/CD template built on GitHub Actions.

## Project Overview

This repository provides a minimal GitHub Actions based CI/CD template.

- CI validates the repository and builds a release archive
- CD deploys that archive to a remote server over SSH
- the template is intentionally lightweight, so it can be reused as the base for other projects

## Workflow

- `pull_request` to `main`: run CI checks and build a release bundle
- `push` to `main`: run CI, build the bundle, then deploy it to a remote server over SSH
- `workflow_dispatch`: allow manual execution from the GitHub Actions UI

The pipeline lives in `.github/workflows/cicd.yml`.

## File Responsibilities

```text
.
|-- .gitignore
|-- app.py
|-- Dockerfile
|-- docker-compose.yml
|-- .github/workflows/cicd.yml
|-- README.md
|-- scripts/ci.sh
|-- scripts/package.sh
`-- scripts/deploy.sh
```

### `README.md`

Project documentation. It explains the workflow, the purpose of each file, required GitHub secrets, and how to use the pipeline.

### `.gitignore`

Ignores local/generated files that should not be committed:

- `.codex`: local tool marker file
- `dist/`: generated build artifacts such as `dist/release.tgz`
- `__pycache__/` and `*.pyc`: Python bytecode
- `.venv/`: local virtual environment

### `app.py`

The minimal runnable example application.

- starts a small HTTP server using only the Python standard library
- serves `GET /` with a simple status page
- serves `GET /healthz` with `ok`
- reads the host and port from command-line flags or environment variables

### `Dockerfile`

Container image definition for the example application.

- uses `python:3.12-slim`
- copies `app.py` into the image
- starts the HTTP server on port `8080`

### `docker-compose.yml`

Local and deployment runtime definition.

- builds the `Dockerfile`
- exposes port `8080`
- sets default app metadata
- restarts the service automatically unless stopped manually

### `.github/workflows/cicd.yml`

The GitHub Actions workflow definition.

- defines CI triggers for `pull_request`, `push`, and `workflow_dispatch`
- runs `scripts/ci.sh` to validate the repository and build the artifact
- uploads `dist/release.tgz` as the CI artifact
- runs `scripts/deploy.sh` on `push` to `main`

### `scripts/ci.sh`

Local and CI entrypoint for validation.

- checks that required project files exist
- syntax-checks all shell scripts with `bash -n`
- compiles `app.py` with `python3 -m py_compile`
- runs a pure Python smoke test against the example app response logic
- calls `scripts/package.sh` to build the release archive
- verifies the generated archive can be read and contains expected files

### `scripts/package.sh`

Builds the release package.

- collects tracked and untracked project files except ignored files
- creates `dist/release.tgz`
- prints the generated artifact path

### `scripts/deploy.sh`

Deployment script used by GitHub Actions.

- reads deployment settings from environment variables
- uploads the artifact to the remote server with `scp`
- extracts it into `DEPLOY_TARGET`
- runs `DEPLOY_POST_DEPLOY` on the remote host
- defaults `DEPLOY_POST_DEPLOY` to `docker compose up -d --build`

### `dist/release.tgz`

Generated artifact directory and archive.

- created by `scripts/ci.sh` or `scripts/package.sh`
- uploaded by GitHub Actions as the CI artifact
- not committed because it is a build output

## Required GitHub Secrets

Configure these in `Settings -> Secrets and variables -> Actions`:

- `DEPLOY_HOST`: remote server hostname or IP
- `DEPLOY_PORT`: SSH port, usually `22`
- `DEPLOY_USER`: SSH user used for deployment
- `DEPLOY_TARGET`: target directory on the remote server, for example `/srv/tiny_cicd`
- `DEPLOY_SSH_KEY`: private SSH key with access to the target server

Optional:

- `DEPLOY_POST_DEPLOY`: shell command executed on the remote host after the bundle is extracted

Example `DEPLOY_POST_DEPLOY` values:

```bash
docker compose -f /srv/tiny_cicd/docker-compose.yml up -d --build
```

```bash
systemctl restart tiny_cicd
```

## How To Use

### 1. Prepare the repository

Clone the repository and review the workflow files:

```bash
git clone https://github.com/yinshuangfei/tiny_cicd.git
cd tiny_cicd
```

If this template will deploy a real application, add that application's source files into this repository. The packaging step will include those files automatically as long as they are not ignored by `.gitignore`.

### 2. Verify locally

Run the same repository checks that CI runs:

```bash
bash scripts/ci.sh
```

This generates `dist/release.tgz`. You can inspect the artifact with:

```bash
tar -tzf dist/release.tgz
```

### 3. Run the example locally

Start the app directly with Python:

```bash
python3 app.py --host 127.0.0.1 --port 8080
```

Then open:

- `http://127.0.0.1:8080/`
- `http://127.0.0.1:8080/healthz`

Or run it with Docker Compose:

```bash
docker compose up --build
```

### 4. Prepare the target server

The remote server should already have:

- an SSH service reachable from GitHub Actions
- a user account matching `DEPLOY_USER`
- write permission to `DEPLOY_TARGET`
- Docker and Docker Compose installed

### 5. Configure GitHub secrets

In the GitHub repository, open `Settings -> Secrets and variables -> Actions` and add:

- `DEPLOY_HOST`
- `DEPLOY_PORT`
- `DEPLOY_USER`
- `DEPLOY_TARGET`
- `DEPLOY_SSH_KEY`
- `DEPLOY_POST_DEPLOY` only if you want to override the default `docker compose up -d --build`

Typical override examples:

```bash
docker compose -f /srv/tiny_cicd/docker-compose.yml up -d --build
```

```bash
systemctl restart tiny_cicd
```

### 6. Trigger CI

Open a pull request to `main`.

The workflow will:

- validate the shell scripts
- package the repository
- upload `dist/release.tgz` as a workflow artifact

### 7. Trigger CD

Merge or push to `main`.

The workflow will:

- rerun CI
- download the packaged artifact
- deploy it to the remote server

You can also trigger the workflow manually from the GitHub Actions page with `workflow_dispatch`.

## What CI Does

`scripts/ci.sh` performs the repository-level checks that make sense for this starter project:

- verifies the expected workflow and scripts exist
- syntax-checks all shell scripts with `bash -n`
- builds a release archive into `dist/release.tgz`
- validates the archive with `tar -tzf`

## What CD Does

`scripts/deploy.sh` deploys `dist/release.tgz` by:

1. copying the bundle to the remote host with `scp`
2. extracting it into `DEPLOY_TARGET`
3. running `DEPLOY_POST_DEPLOY` if it is configured

## Local Verification

Run the same repository checks locally:

```bash
bash scripts/ci.sh
```

This creates `dist/release.tgz`, which is the same artifact uploaded by the workflow.
