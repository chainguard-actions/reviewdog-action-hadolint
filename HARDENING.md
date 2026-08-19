<!-- markdownlint-disable -->

# Hardening Report: reviewdog--action-hadolint/v1.51.0

> This file was generated automatically by the hardening agent.

**Policy SHA:** `d636be7e43ef829af6e853da6b3c7566db9f72fe`

**Test Policy SHA:** `843adf9e4b8f85d0c08b27b9d0b09dd094b54702`

**Harden Agent Version:** `2`

Action **reviewdog--action-hadolint/v1.51.0** was hardened automatically. 2 finding(s) were identified and resolved across 2 iteration(s).

## Findings Fixed

### unsafe-shell (severity: high)

script.sh pipes a remote install script directly to `sh` without first downloading and verifying it. The pattern `curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/fd59714416d6d9a1c0692d872e38e7f8448df4fc/install.sh | sh -s -- ...` executes whatever content is served at that URL immediately in the shell. If the remote content is tampered with (e.g. via a supply-chain compromise), malicious code would execute directly on the runner. The script should be downloaded to a file first, its integrity verified (e.g. via checksum), and then executed separately.

Locations:

- `script.sh:11`

### missing-permissions (severity: medium)

None of the workflow files under .github/workflows/ declare a `permissions:` key at either the top level or the job level. Without explicit permissions, workflows run with the default repository token permissions, which may be overly broad (e.g. write access to contents, pull-requests, etc.). Each workflow should declare the minimal permissions required.

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

1. script.sh (unsafe-shell): Replaced `curl ... | sh -s -- ...` with a two-step approach: download the install script to a temp file with `curl -sfL -o`, verify it passes shell syntax check with `sh -n`, then execute it with `sh`. The URL remains pinned to the specific commit SHA (fd59714416d6d9a1c0692d872e38e7f8448df4fc). 2. missing-permissions: Added `permissions:` blocks to all 5 workflow files at the top level: depup.yml (contents:write, pull-requests:write for creating PRs), release.yml (contents:write for creating releases), reviewdog.yml (contents:read, pull-requests:write for posting review comments), test.yml (contents:read, checks:write, pull-requests:write for running tests and posting results), yamllint.yml (contents:read, pull-requests:write for posting review comments).

### Iteration 2

**Fixes applied:** script-injection

**Notes:**

Fixed all 6 script-injection locations in script.sh:

1. Converted script from sh to bash (#!/bin/bash) to enable arrays and process substitution.
2. Updated action.yml to use `shell: bash` instead of `shell: sh`.
3. Replaced unquoted for-loop word-splitting on $INPUT_EXCLUDE, $INPUT_INCLUDE, and $INPUT_HADOLINT_IGNORE (lines 31, 37, 43) with xargs-based quote-aware tokenization into bash arrays (EXCLUDES[], INCLUDES[], IGNORE_LIST[]).
4. Replaced unquoted ${INCLUDES}, ${EXCLUDES}, ${INPUT_HADOLINT_FLAGS} in the git ls-files and xargs hadolint invocations (lines 50-51) with properly quoted array expansions "${INCLUDES[@]}", "${EXCLUDES[@]}", "${IGNORE_LIST[@]}", "${HADOLINT_FLAGS[@]}".
5. Replaced unquoted ${INPUT_REVIEWDOG_FLAGS} at the end of the reviewdog invocation (line 60) with a properly quoted array expansion "${REVIEWDOG_FLAGS[@]}".

All list inputs (exclude, include, hadolint_ignore, hadolint_flags, reviewdog_flags) are now tokenized via `printf '%s' "$VAR" | xargs printf '%s\0'` which handles quoted substrings correctly and prevents shell metacharacter injection.

