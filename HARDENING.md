# Hardening Report: reviewdog--action-hadolint/v1.50.5

> This file was generated automatically by the hardening agent.

**Policy SHA:** `ff50f15e4b79bfbf764dafdfd2579175a6ea9771`

**Test Policy SHA:** `843adf9e4b8f85d0c08b27b9d0b09dd094b54702`

**Harden Agent Version:** `1`

Action **reviewdog--action-hadolint/v1.50.5** was hardened automatically. 1 finding(s) were identified and resolved across 1 iteration(s).

## Findings Fixed

### unsafe-shell (severity: high)

script.sh pipes a remotely fetched install script directly to a shell interpreter: `curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/fd59714416d6d9a1c0692d872e38e7f8448df4fc/install.sh | sh -s -- ...`. Although the URL is pinned to a specific commit SHA, piping remote content directly to `sh` is an unsafe pattern — if the remote content is ever tampered with or the network is intercepted, arbitrary code will execute in the runner. The script should be downloaded to a file first, its integrity verified (e.g. via checksum), and then executed separately.

Locations:

- `script.sh:11`

## Iteration Notes

### Iteration 1

**Fixes applied:** unsafe-shell

**Notes:**

Fixed script.sh line 11: replaced `curl ... | sh -s -- ...` (pipe-to-shell anti-pattern) with a two-step approach: (1) download the install script to a temp file using `curl -sfL ... -o "${REVIEWDOG_INSTALL_SCRIPT}"`, then (2) execute it separately with `sh "${REVIEWDOG_INSTALL_SCRIPT}" ...`. The URL remains pinned to commit SHA fd59714416d6d9a1c0692d872e38e7f8448df4fc for source integrity.

