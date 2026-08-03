<!-- markdownlint-disable -->

# Hardening Report: reviewdog--action-hadolint/v1.52.0

> This file was generated automatically by the hardening agent.

**Policy SHA:** `d636be7e43ef829af6e853da6b3c7566db9f72fe`

**Test Policy SHA:** `843adf9e4b8f85d0c08b27b9d0b09dd094b54702`

**Harden Agent Version:** `2`

Action **reviewdog--action-hadolint/v1.52.0** was hardened automatically. 3 finding(s) were identified and resolved across 1 iteration(s).

## Findings Fixed

### unsafe-shell (severity: high)

script.sh pipes a remote install script directly to `sh` without first downloading and verifying it. The pattern `curl -sfL https://raw.githubusercontent.com/.../install.sh | sh -s -- ...` executes whatever content the remote URL returns, making the action vulnerable to supply-chain attacks if the URL is compromised or redirected.

Locations:

- `script.sh:11`

### script-injection (severity: high)

Rule (b) violation: Multiple unquoted shell variable expansions of untrusted input values (sourced from `inputs.*` via the action.yml env: block) in script.sh allow shell metacharacter injection. Specifically: (1) `for exclude_path in $INPUT_EXCLUDE` (line 26) — unquoted word-splitting on attacker-controlled input; (2) `for include_path in $INPUT_INCLUDE` (line 31) — same; (3) `for rule in $INPUT_HADOLINT_IGNORE` (line 36) — same; (4) `git ls-files ${INCLUDES} --ignored --cached ${EXCLUDES}` (line 40) — unquoted expansion of attacker-derived variables; (5) `xargs hadolint -f json ${INPUT_HADOLINT_FLAGS}` (line 41) — unquoted; (6) `${INPUT_REVIEWDOG_FLAGS}` (line 51) — unquoted. All of these should be double-quoted (e.g. `"$INPUT_EXCLUDE"`) or handled with proper quoting to prevent shell metacharacter injection.

Locations:

- `script.sh:26`
- `script.sh:31`
- `script.sh:36`
- `script.sh:40`
- `script.sh:41`
- `script.sh:51`

### missing-permissions (severity: medium)

None of the workflow files define a top-level `permissions:` key, and no job within any workflow defines job-level `permissions:`. Without explicit permissions, workflows run with the default repository token permissions (which may be `write-all` depending on repository settings), violating the principle of least privilege. All five workflow files are affected: depup.yml, release.yml, reviewdog.yml, test.yml, and yamllint.yml.

Locations:

- `.github/workflows/depup.yml:1`
- `.github/workflows/release.yml:1`
- `.github/workflows/reviewdog.yml:1`
- `.github/workflows/test.yml:1`
- `.github/workflows/yamllint.yml:1`

## Iteration Notes

### Iteration 1

**Fixes applied:** unsafe-shell, script-injection, missing-permissions

**Notes:**

1. unsafe-shell (script.sh line 11): Replaced `curl ... | sh` with a two-step approach: download the install script to a temp file with `curl -sfL ... -o "${TEMP_PATH}/install_reviewdog.sh"`, then execute it separately with `sh "${TEMP_PATH}/install_reviewdog.sh" ...`. 2. script-injection (script.sh lines 26,31,36,40,41,51): Rewrote the script to use bash arrays and `read -ra` for all space-separated list inputs (INPUT_EXCLUDE, INPUT_INCLUDE, INPUT_HADOLINT_IGNORE, INPUT_HADOLINT_FLAGS, INPUT_REVIEWDOG_FLAGS). All array expansions use `"${array[@]}"` syntax. Changed shell from `sh` to `bash` in action.yml and updated shebang to `#!/bin/bash`. Removed the shellcheck-disable comment since issues are properly fixed. 3. missing-permissions: Added top-level `permissions:` blocks to all 5 workflow files with minimal required permissions: depup.yml (contents: write, pull-requests: write), release.yml (contents: write), reviewdog.yml (contents: read, pull-requests: write), test.yml (contents: read, checks: write, pull-requests: write), yamllint.yml (contents: read, pull-requests: write).

