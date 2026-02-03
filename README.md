# CybeDefend Action

![GitHub release](https://img.shields.io/github/v/release/CybeDefend/cybedefend-action)

Run security scans easily in your CI/CD pipelines using the official CybeDefend CLI, powered by Docker.

This action uses the [CybeDefend CLI](https://github.com/CybeDefend/cybedefend-cli) via the Docker image [ghcr.io/cybedefend/cybedefend-cli:v1.0.10](https://github.com/CybeDefend/cybedefend-cli/pkgs/container/cybedefend-cli).

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
| `branch` | Branch name to associate with the scan (e.g., `main`, `develop`, `feature/my-feature`) | ✅ | `main` |
| `policy_check` | Enable/disable policy evaluation after scan | ❌ | `true` |
| `policy_timeout` | Timeout in seconds for policy evaluation | ❌ | `300` |
| `show_policy_vulns` | Show affected vulnerabilities in policy evaluation output | ❌ | `true` |
| `show_all_policy_vulns` | Show all affected vulnerabilities without limit | ❌ | `false` |

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
          branch: ${{ github.ref_name }}
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
          branch: ${{ github.ref_name }}
          # api_url takes precedence over region when both are provided
          api_url: https://api-us.cybedefend.com
```

### Scan with Branch Tracking

```yaml
name: CybeDefend Security Scan with Branch

on:
  push:
    branches:
      - main
      - develop
      - 'feature/**'
  pull_request:
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
          branch: ${{ github.head_ref || github.ref_name }}
```

### Scan with Policy Evaluation

```yaml
name: CybeDefend Security Scan with Policy Enforcement

on:
  push:
    branches:
      - main
  pull_request:
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
          branch: ${{ github.head_ref || github.ref_name }}
          # Policy evaluation options
          policy_check: true
          policy_timeout: 300
          show_policy_vulns: true
          show_all_policy_vulns: false
```

### Scan without Policy Evaluation

```yaml
name: CybeDefend Security Scan (No Policy Check)

on:
  push:
    branches:
      - develop

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
          branch: ${{ github.ref_name }}
          policy_check: false
```

## Notes

- Default API endpoint is `https://api-us.cybedefend.com`. Use `region: eu` to target the EU endpoint, or set a custom `api_url`.
- URL precedence: `--api-url` > `CYBEDEFEND_API_URL` > config `api_url` > value derived from region.
- **Policy Evaluation**: Enabled by default in v1.0.9. If any policy has a BLOCK action with violations, the action will exit with code 1. Use `policy_check: false` to disable.
