# Hardening Report: reviewdog--action-hadolint/v1.50.5

> This file was generated automatically by the hardening agent.

**Policy SHA:** `ff50f15e4b79bfbf764dafdfd2579175a6ea9771`

**Test Policy SHA:** `843adf9e4b8f85d0c08b27b9d0b09dd094b54702`

**Harden Agent Version:** `1`

Action **reviewdog--action-hadolint/v1.50.5** was hardened automatically. 1 finding(s) were identified and resolved across 1 iteration(s).

## Findings Fixed

### unsafe-shell (severity: high)

In script.sh line 11, a remote install script is fetched with `curl` and piped directly to `sh` for execution: `curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/fd59714416d6d9a1c0692d872e38e7f8448df4fc/install.sh | sh -s -- ...`. Even though the URL is pinned to a specific commit SHA in the path, the content is still executed without being saved to disk and inspected first. This pattern allows a compromised or man-in-the-middle response to execute arbitrary code on the runner.

Locations:

- `script.sh:11`

## Iteration Notes

### Iteration 1

**Fixes applied:** unsafe-shell

**Notes:**

Fixed the unsafe curl-pipe-to-shell pattern in script.sh line 11. Changed from `curl -sfL <url> | sh -s -- ...` to downloading the script to a temporary file first (`curl -sfL <url> -o "${REVIEWDOG_INSTALL_SCRIPT}"`), then executing it separately (`sh "${REVIEWDOG_INSTALL_SCRIPT}" ...`). The URL remains pinned to the same specific commit SHA (fd59714416d6d9a1c0692d872e38e7f8448df4fc), and all original arguments are preserved.

