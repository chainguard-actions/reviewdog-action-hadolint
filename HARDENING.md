<!-- markdownlint-disable -->

# Hardening Report: reviewdog--action-hadolint/v1

> This file was generated automatically by the hardening agent.

**Policy SHA:** `d636be7e43ef829af6e853da6b3c7566db9f72fe`

**Test Policy SHA:** `843adf9e4b8f85d0c08b27b9d0b09dd094b54702`

**Harden Agent Version:** `2`

Action **reviewdog--action-hadolint/v1** was hardened automatically. 1 finding(s) were identified and resolved across 1 iteration(s).

## Findings Fixed

### unsafe-shell (severity: high)

script.sh, which the composite action's run step calls, downloads a remote script and pipes it straight into a shell: `curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/fd59714416d6d9a1c0692d872e38e7f8448df4fc/install.sh | sh -s -- -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}"`. The URL is pinned to a commit, but the content runs without being saved to a file first. It should be downloaded to a file, checked, and then run as a separate step.

Locations:

- `script.sh:11`

## Iteration Notes

### Iteration 1

**Fixes applied:** unsafe-shell

**Notes:**

script.sh: reviewdog install.sh (pinned commit URL) is now downloaded to a temp file with curl -o, then run with 'sh FILE -b "$TEMP_PATH" "$REVIEWDOG_VERSION"' (dropped '-s --'), then removed.

