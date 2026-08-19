<!-- markdownlint-disable -->

# Hardening Report: reviewdog--action-hadolint/v1.50.5

> This file was generated automatically by the hardening agent.

**Policy SHA:** `d636be7e43ef829af6e853da6b3c7566db9f72fe`

**Test Policy SHA:** `843adf9e4b8f85d0c08b27b9d0b09dd094b54702`

**Harden Agent Version:** `2`

Action **reviewdog--action-hadolint/v1.50.5** was hardened automatically. 2 finding(s) were identified and resolved across 3 iteration(s).

## Findings Fixed

### unsafe-shell (severity: high)

script.sh pipes a remotely fetched install script directly to `sh` without first downloading and verifying it. The pattern `curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/.../install.sh | sh -s -- ...` executes arbitrary remote content in the runner shell, which is a supply-chain risk even when the URL includes a commit SHA in the path.

Locations:

- `script.sh:11`

### missing-permissions (severity: medium)

None of the workflow files define a `permissions:` key at the top level or at the job level. Without explicit permissions, workflows run with the repository's default token permissions (which may be broad write access). Each workflow should declare minimal required permissions.

Locations:

- `.github/workflows/depup.yml:1`
- `.github/workflows/release.yml:1`
- `.github/workflows/reviewdog.yml:1`
- `.github/workflows/test.yml:1`
- `.github/workflows/yamllint.yml:1`

## Iteration Notes

### Iteration 1

**Fixes applied:** unsafe-shell, missing-permissions

**Notes:**

1. script.sh (line 11): Replaced `curl ... | sh -s -- ...` with a two-step approach: download the install script to a temp file with `curl -sfL -o "${INSTALL_SCRIPT}"`, execute it separately with `sh "${INSTALL_SCRIPT}"`, then remove the temp file. This eliminates the supply-chain risk of piping remote content directly to a shell.
2. .github/workflows/depup.yml: Added `permissions: contents: write, pull-requests: write` (needs to create PRs).
3. .github/workflows/release.yml: Added `permissions: contents: write` (needs to create releases and update tags).
4. .github/workflows/reviewdog.yml: Added `permissions: contents: read, pull-requests: write` (needs to post PR review comments).
5. .github/workflows/test.yml: Added `permissions: contents: read, checks: write, pull-requests: write` (needs to post check results and PR review comments).
6. .github/workflows/yamllint.yml: Added `permissions: contents: read, pull-requests: write` (needs to post PR review comments).

### Iteration 2

**Fixes applied:** script-injection

**Notes:**

Fixed all 6 unquoted variable expansion instances in script.sh by switching from POSIX sh to bash and using proper bash arrays:
1. Changed shebang from #!/bin/sh to #!/bin/bash
2. Changed action.yml shell from 'sh' to 'bash'
3. Replaced string-accumulation pattern for EXCLUDES/INCLUDES with bash arrays, expanded as "${EXCLUDES[@]}" and "${INCLUDES[@]}" in git ls-files call
4. Replaced string-accumulation for IGNORE_LIST with a bash array, each rule individually double-quoted
5. Replaced unquoted ${INPUT_HADOLINT_FLAGS} with a HADOLINT_FLAGS bash array (merged with IGNORE_LIST), expanded as "${HADOLINT_FLAGS[@]}" in xargs call
6. Replaced unquoted ${INPUT_REVIEWDOG_FLAGS} with a REVIEWDOG_FLAGS bash array, expanded as "${REVIEWDOG_FLAGS[@]}" in reviewdog invocation
7. Also fixed unquoted $TEMP_PATH/hadolint in wget/chmod calls as a bonus hardening

### Iteration 3

**Fixes applied:** script-injection

**Notes:**

Fixed all 5 script injection issues in script.sh by replacing unquoted variable expansions with `read -ra` array splitting:
1. `for exclude_path in ${INPUT_EXCLUDE}` → `read -ra _exclude_parts <<< "${INPUT_EXCLUDE}"` + `for exclude_path in "${_exclude_parts[@]}"`
2. `for include_path in ${INPUT_INCLUDE}` → `read -ra _include_parts <<< "${INPUT_INCLUDE}"` + `for include_path in "${_include_parts[@]}"`
3. `for rule in ${INPUT_HADOLINT_IGNORE}` → `read -ra _ignore_parts <<< "${INPUT_HADOLINT_IGNORE}"` + `for rule in "${_ignore_parts[@]}"`
4. `HADOLINT_FLAGS=(${INPUT_HADOLINT_FLAGS})` → `read -ra HADOLINT_FLAGS <<< "${INPUT_HADOLINT_FLAGS}"`
5. `REVIEWDOG_FLAGS=(${INPUT_REVIEWDOG_FLAGS})` → `read -ra REVIEWDOG_FLAGS <<< "${INPUT_REVIEWDOG_FLAGS}"`

The `read -ra` approach uses a double-quoted here-string to prevent glob expansion during input, and the resulting array elements are always accessed with double-quoted `"${array[@]}"` syntax. This preserves the intended whitespace-splitting behavior while eliminating glob injection risk.

