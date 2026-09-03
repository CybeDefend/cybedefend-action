# CybeDefend Action

![GitHub release](https://img.shields.io/github/v/release/CybeDefend/cybedefend-action)

Run security scans easily in your CI/CD pipelines using the official CybeDefend CLI, powered by Docker.

This action uses the [CybeDefend CLI](https://github.com/CybeDefend/cybedefend-cli) via the Docker image [ghcr.io/cybedefend/cybedefend-cli:v2.0.3](https://github.com/CybeDefend/cybedefend-cli/pkgs/container/cybedefend-cli).

## Usage

```yaml
- uses: CybeDefend/cybedefend-action@v2
  with:
    pat: ${{ secrets.CYBEDEFEND_PAT }}
    project_id: ${{ secrets.CYBEDEFEND_PROJECT_ID }}
```

## Inputs

| Name | Description | Required | Default |
|:---|:---|:---|:---|
| `pat` | Personal Access Token (PAT) | ✅ | |
| `project_id` | Project ID for the scan | ✅ | |
| `wait` | Wait for scan completion | ❌ | `true` |
| `interval` | Interval in seconds between status checks | ❌ | `5` |
| `break_on_fail` | Exit with error code if scan fails | ❌ | `false` |
| `break_on_severity` | Exit with error code if vulnerabilities of specified severity or above are detected (critical, high, medium, low, none) | ❌ | `` |
| `region` | Region for API endpoints (`us` or `eu`). Ignored if `api_url` is set. | ❌ | `` |
| `api_url` | Custom API base URL, **https only** (overrides region). | ❌ | `` |
| `branch` | Branch name to associate with the scan (e.g., `main`, `develop`, `feature/my-feature`) | ✅ | `main` |
| `policy_check` | Enable/disable policy evaluation after scan | ❌ | `true` |
| `policy_timeout` | Timeout in seconds for policy evaluation | ❌ | `300` |
| `show_policy_vulns` | Show affected vulnerabilities in policy evaluation output | ❌ | `true` |
| `show_all_policy_vulns` | Show all affected vulnerabilities without limit | ❌ | `false` |
| `report_format` | Report to export after the scan (`none`, `sarif`, `json`, `html`, `markdown`) | ❌ | `none` |
| `report_type` | Scan types to include in the report (`all`, `sast`, `sca`, `iac`, `secret`, `cicd`, `container`) | ❌ | `all` |
| `report_filename` | Report file name, written into the workspace. Must be a plain file name, without a path. | ❌ | `cybedefend-results.<ext>` |

## Outputs

| Name | Description |
|:---|:---|
| `report_file` | Path of the exported report, relative to the workspace — ready for `upload-sarif` or `upload-artifact` |
| `report_format` | Format actually exported, for conditional steps |

Both are set only when `report_format` is not `none` and the export succeeded.

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
        uses: CybeDefend/cybedefend-action@v2
        with:
          pat: ${{ secrets.CYBEDEFEND_PAT }}
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
        uses: CybeDefend/cybedefend-action@v2
        with:
          pat: ${{ secrets.CYBEDEFEND_PAT }}
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
        uses: CybeDefend/cybedefend-action@v2
        with:
          pat: ${{ secrets.CYBEDEFEND_PAT }}
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
        uses: CybeDefend/cybedefend-action@v2
        with:
          pat: ${{ secrets.CYBEDEFEND_PAT }}
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
        uses: CybeDefend/cybedefend-action@v2
        with:
          pat: ${{ secrets.CYBEDEFEND_PAT }}
          project_id: ${{ secrets.CYBEDEFEND_PROJECT_ID }}
          branch: ${{ github.ref_name }}
          policy_check: false
```

### Publishing findings to the Code scanning tab

`report_format: sarif` writes a SARIF file into the workspace after the scan and
exposes its path as an output, so `upload-sarif` can consume it with no glue:

```yaml
name: CybeDefend Security Scan

on: [push, pull_request]

permissions:
  contents: read
  security-events: write   # required by upload-sarif

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run CybeDefend Security Scan
        id: cybedefend
        uses: CybeDefend/cybedefend-action@v2
        with:
          pat: ${{ secrets.CYBEDEFEND_PAT }}
          project_id: ${{ secrets.CYBEDEFEND_PROJECT_ID }}
          branch: ${{ github.head_ref || github.ref_name }}
          break_on_severity: high
          report_format: sarif

      - name: Upload results to Code scanning
        uses: github/codeql-action/upload-sarif@v3
        if: always()   # the report is exported even when the gate above fails
        with:
          sarif_file: ${{ steps.cybedefend.outputs.report_file }}
```

The report is exported **after** the scan and covers the scanned branch only. It
is written even when `break_on_fail` / `break_on_severity` fails the step — that
is exactly when the findings are wanted — which is why the `upload-sarif` step
needs `if: always()`. An export that fails is reported as a warning and never
turns a passing scan into a failing job.

To keep the report as a build artifact instead:

```yaml
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: cybedefend-report
          path: ${{ steps.cybedefend.outputs.report_file }}
```

## Input validation

Inputs are frequently wired from event data (`github.head_ref` on a pull request
is controlled by the PR author), so the entrypoint treats every input as
untrusted:

- The CLI is invoked with **positional parameters**, so one input is always
  exactly one argument — a value containing spaces, tabs, `*` or a leading `-`
  can never turn into extra CLI flags, and never expands against the filenames
  of the repository being scanned.
- Inputs with a documented domain are checked before the scan starts, and the
  action fails with a clear message instead of passing the value through:

  | Input | Accepted |
  |:---|:---|
  | `api_url` | `https://` + a plain host (optional port and path). No other scheme, no embedded credentials (`user@host`), no whitespace |
  | `region` | `us`, `eu` |
  | `break_on_severity` | `critical`, `high`, `medium`, `low`, `none` |
  | `interval`, `policy_timeout` | digits only (seconds) |
  | `report_format` | `none`, `sarif`, `json`, `html`, `markdown` |
  | `report_type` | `all`, `sast`, `sca`, `iac`, `secret`, `cicd`, `container` |
  | `report_filename` | a plain file name: letters, digits, `.`, `_`, `-`. No `/`, no `..`, no leading `-` |

  `api_url` is the value that decides which host receives your `pat`, which is
  why `http://` is rejected outright. `report_filename` is written inside the
  workspace, so a path separator or a `..` is refused rather than allowed to
  place a file elsewhere on the runner.

- `wait`, `break_on_fail`, `policy_check`, `show_policy_vulns` and
  `show_all_policy_vulns` act only on their documented value; anything else
  falls back to the default.

Tests live in [`tests/entrypoint.bats`](tests/entrypoint.bats) and run in CI
against both `dash` and `bash`:

```bash
bats tests/
shellcheck --shell=sh entrypoint.sh
```

## Notes

- Default API endpoint is `https://api-us.cybedefend.com`. Use `region: eu` to target the EU endpoint, or set a custom `api_url`.
- URL precedence: `--api-url` > `CYBEDEFEND_API_URL` > config `api_url` > value derived from region.
- **Policy Evaluation**: Enabled by default in v1.0.9. If any policy has a BLOCK action with violations, the action will exit with code 1. Use `policy_check: false` to disable.
- **Report export**: `report_format` defaults to `none`, so the action behaves exactly as before unless a report is asked for. The export runs the same CLI the scan ran, from the same image, against the same host — no second Docker invocation and no CLI version to keep in sync in your workflow.
- **Breaking in v2**: `api_key` input has been replaced by `pat`. API key authentication is no longer supported by the CybeDefend API.
