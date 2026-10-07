# Workflows

`lint.yml` runs on every push to `main` and on every pull request:

- **ShellCheck** — static analysis of all `*.sh` files at `warning` severity
- **bash -n** — parses every script so a syntax error can never reach `main`

A pull request that fails either job should not be merged.
