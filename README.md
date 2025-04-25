# CybeDefend Action

![GitHub release](https://img.shields.io/github/v/release/CybeDefend/cybedefend-action)

Run security scans easily in your CI/CD pipelines using the official CybeDefend CLI, powered by Docker.

This action uses the [CybeDefend CLI](https://github.com/CybeDefend/cybedefend-cli) via the Docker image [ghcr.io/cybedefend/cybedefend-cli:latest](https://github.com/CybeDefend/cybedefend-cli/pkgs/container/cybedefend-cli).

## Usage

```yaml
- uses: CybeDefend/cybedefend-action@v1
  with:
    api-key: ${{ secrets.CYBEDEFEND_API_KEY }}
    project-id: ${{ secrets.CYBEDEFEND_PROJECT_ID }}
    dir: ./your-project-directory
```

## Inputs

| Name | Description | Required | Default |
|:---|:---|:---|:---|
| `api-key` | API Key for authentication | ✅ | |
| `project-id` | Project ID for the scan | ✅ | |
| `dir` | Directory to scan | ❌ | |
| `file` | Pre-zipped file to scan | ❌ | |
| `ci` | Enable CI/CD friendly output (no colors, ASCII art) | ❌ | `true` |

## Example Workflow

```yaml
name: CybeDefend Security Scan

on:
  push:
    branches:
      - main

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Run CybeDefend Security Scan
        uses: CybeDefend/cybedefend-action@v1
        with:
          api-key: ${{ secrets.CYBEDEFEND_API_KEY }}
          project-id: ${{ secrets.CYBEDEFEND_PROJECT_ID }}
          dir: ./
          