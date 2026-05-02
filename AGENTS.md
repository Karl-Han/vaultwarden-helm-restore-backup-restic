# Repository Guidelines

## Project Structure & Module Organization

This repository has three active areas:

- `main.py`: Python CLI for Vaultwarden backup and restore orchestration.
- `devops/k8s/`: prototype Kubernetes manifests used to validate the raw workflow first.
- `devops/helm/`: Helm chart that packages the validated prototype into reusable templates.

Supporting files:

- `devops/Dockerfile.restic`: custom image with Python, Restic, and rclone.
- `docs/`: Sphinx documentation and operational guides.
- `envrc.template`: expected runtime environment variables.
- `data/`: local example assets such as `rclone.conf` and TLS test files.

`devops/deprecated/` is historical and should not be used for new work.

## Build, Test, and Development Commands

- `python main.py --help`: show CLI usage.
- `python main.py backup`: run the backup flow locally when env vars are set.
- `python main.py restore`: run the restore flow locally.
- `helm lint devops/helm`: validate Helm chart structure.
- `helm template test-release devops/helm`: render manifests for review.
- `make -C docs html`: build the documentation locally.

When changing Helm templates, always run both `helm lint` and `helm template`.

## Coding Style & Naming Conventions

Use 4-space indentation in Python and keep code compatible with Python 3.12. Prefer small functions, explicit error handling, and `click` for CLI behavior. In Helm templates and YAML, keep keys descriptive and add comments in `devops/helm/values.yaml` unless the meaning is obvious.

In repository documentation, use relative file references such as `./devops/helm/README.md` instead of absolute filesystem paths.

Naming patterns in recent commits use scoped prefixes, for example:

- `[docs][env] init docs`
- `[devops][helm] first version of working helm chart`

Follow that style for new commits when practical.

## Testing Guidelines

There is no dedicated unit test suite yet. Validation is currently operational:

- render and lint the Helm chart
- exercise `main.py` only with safe test inputs
- rebuild docs when changing `docs/`

If you add tests later, place them in a `tests/` directory and keep names explicit, such as `test_backup_cli.py`.

## Commit & Pull Request Guidelines

Keep commits focused by area: Python CLI, Helm, docs, or raw manifests. Pull requests should explain the operational impact, changed resources, required env vars or secrets, and any manual validation performed. Include rendered Helm output or command summaries when the change affects deployment behavior.
