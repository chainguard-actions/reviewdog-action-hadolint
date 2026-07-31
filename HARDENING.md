<!-- markdownlint-disable -->

# Hardening Report: reviewdog--action-hadolint/v1.53.0

> This file was generated automatically by the hardening agent.

**Policy SHA:** `d636be7e43ef829af6e853da6b3c7566db9f72fe`

**Test Policy SHA:** `843adf9e4b8f85d0c08b27b9d0b09dd094b54702`

**Harden Agent Version:** `2`

Action **reviewdog--action-hadolint/v1.53.0** was hardened automatically. 3 finding(s) were identified and resolved across 2 iteration(s).

## Findings Fixed

### unsafe-shell (severity: high)

script.sh pipes a remote install script directly to `sh` without first downloading and verifying it. The pattern `curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/fd59714416d6d9a1c0692d872e38e7f8448df4fc/install.sh | sh -s -- ...` executes whatever content is served at that URL in the runner shell. Even though the URL includes a commit SHA in the path, the content is still executed without integrity verification (e.g., no checksum check). This is a supply-chain risk.

Locations:

- `script.sh:11`

### script-injection (severity: high)

Rule (b) violation: script.sh expands multiple INPUT_* environment variables (sourced from `inputs.*` in action.yml) without double-quoting them in shell contexts. Unquoted expansions allow shell metacharacters (`;`, `|`, `&`, `$(...)`, whitespace, glob chars) embedded in user-controlled input values to be interpreted by the shell, enabling command injection.

Offending lines:
- Line 26: `for exclude_path in $INPUT_EXCLUDE` — unquoted word-split iteration over attacker-controlled input
- Line 31: `for include_path in $INPUT_INCLUDE` — unquoted word-split iteration over attacker-controlled input
- Line 36: `for rule in $INPUT_HADOLINT_IGNORE` — unquoted word-split iteration over attacker-controlled input
- Line 42: `git ls-files ${INCLUDES} --ignored --cached ${EXCLUDES}` — unquoted expansion of variables built from attacker-controlled inputs
- Line 43: `| xargs hadolint -f json ${INPUT_HADOLINT_FLAGS}` — unquoted expansion of attacker-controlled flags
- Line 50: `${INPUT_REVIEWDOG_FLAGS}` — unquoted expansion of attacker-controlled reviewdog flags

Locations:

- `script.sh:26`
- `script.sh:31`
- `script.sh:36`
- `script.sh:42`
- `script.sh:43`
- `script.sh:50`

### missing-permissions (severity: medium)

None of the workflow files define a top-level `permissions:` block, and no individual job within them defines job-level `permissions:` either. Without explicit permission scoping, workflows run with the repository's default token permissions (which may include broad write access), violating the principle of least privilege.

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

1. unsafe-shell: Replaced `curl ... | sh` pipe in script.sh with a two-step approach: download the reviewdog install script to a temp file first, then execute it separately with `sh`. 2. script-injection: Rewrote script.sh to use bash arrays (EXCLUDES, INCLUDES, IGNORE_FLAGS, HADOLINT_FLAGS, REVIEWDOG_FLAGS) instead of unquoted string concatenation. All variable expansions are now properly double-quoted. Changed shebang to #!/bin/bash and updated action.yml shell from 'sh' to 'bash'. Used `read -ra` to safely split flag inputs into arrays. 3. missing-permissions: Added top-level permissions blocks to all 5 workflow files with minimal required permissions: depup.yml (contents:write, pull-requests:write), release.yml (contents:write), reviewdog.yml/test.yml/yamllint.yml (contents:read, checks:write, pull-requests:write).

### Iteration 2

**Fixes applied:** script-injection

**Notes:**

Fixed three unquoted for-loop expansions in script.sh (lines 33, 38, 43) that expanded INPUT_EXCLUDE, INPUT_INCLUDE, and INPUT_HADOLINT_IGNORE without double-quoting, allowing shell metacharacter injection. Replaced each bare `for var in ${INPUT_VAR}; do` pattern with a safe `read -ra` approach: guard with `[ -n "${INPUT_VAR}" ]`, split into a named array using `read -ra _array <<< "${INPUT_VAR}"`, then iterate with `for var in "${_array[@]}"; do`. This prevents shell metacharacters in attacker-controlled input values from being interpreted by the shell, consistent with the existing safe pattern already used for INPUT_HADOLINT_FLAGS and INPUT_REVIEWDOG_FLAGS later in the same script.

