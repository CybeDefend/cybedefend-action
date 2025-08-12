# CybeDefend Action

![GitHub release](https://img.shields.io/github/v/release/CybeDefend/cybedefend-action)

Run security scans easily in your CI/CD pipelines using the official CybeDefend CLI, powered by Docker.

This action uses the [CybeDefend CLI](https://github.com/CybeDefend/cybedefend-cli) via the Docker image [ghcr.io/cybedefend/cybedefend-cli:v1.0.5](https://github.com/CybeDefend/cybedefend-cli/pkgs/container/cybedefend-cli).

## Usage

```yaml
- uses: CybeDefend/cybedefend-action@v1
  with:
    api_key: ${{ secrets.CYBEDEFEND_API_KEY }}
    project_id: ${{ secrets.CYBEDEFEND_PROJECT_ID }}
```

## Inputs

| Name | Description | Required | Default |
|:---|:---|:---|:---|
| `api_key` | API Key for authentication | ✅ | |
| `project_id` | Project ID for the scan | ✅ | |
| `wait` | Wait for scan completion | ❌ | `true` |
| `interval` | Interval in seconds between status checks | ❌ | `5` |
| `break_on_fail` | Exit with error code if scan fails | ❌ | `false` |
| `break_on_severity` | Exit with error code if vulnerabilities of specified severity or above are detected (critical, high, medium, low, none) | ❌ | `` |
| `region` | Region for API endpoints (`us` or `eu`). Ignored if `api_url` is set. | ❌ | `` |
| `api_url` | Custom API base URL (overrides region). | ❌ | `` |

## Example Workflow

### Basic Scan

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
          api_key: ${{ secrets.CYBEDEFEND_API_KEY }}
          project_id: ${{ secrets.CYBEDEFEND_PROJECT_ID }}
          region: us
```

### Advanced Scan with CI/CD Breaking

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
          api_key: ${{ secrets.CYBEDEFEND_API_KEY }}
          project_id: ${{ secrets.CYBEDEFEND_PROJECT_ID }}
          break_on_fail: true
          break_on_severity: high
          interval: 10
          # api_url takes precedence over region when both are provided
          api_url: https://api-us.cybedefend.com

## Notes

- Default API endpoint is `https://api-us.cybedefend.com`. Use `region: eu` to target the EU endpoint, or set a custom `api_url`.
- URL precedence: `--api-url` > `CYBEDEFEND_API_URL` > config `api_url` > value derived from region.
```
