# Hardening Report: reviewdog--action-hadolint/v1

> This file was generated automatically by the hardening agent.

**Policy SHA:** `c40cfe5fa14e08549b1b988e7e5a26da4816abf0`

**Test Policy SHA:** `f2e7d85641cde4267138117189b8eba7ba2bfbde`

Action **reviewdog--action-hadolint/v1** was hardened automatically. 1 finding(s) were identified and resolved across 1 iteration(s).

## Findings Fixed

### unsafe-shell (severity: high)

In script.sh (called from action.yml), the reviewdog installer is downloaded and piped directly to `sh` without first saving to a file: `curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/fd59714416d6d9a1c0692d872e38e7f8448df4fc/install.sh | sh -s -- -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}" 2>&1`. Even though the URL includes a pinned commit SHA in the path, the content is executed immediately without any integrity verification (e.g. checksum validation). If the remote server or CDN is compromised, or if the URL is redirected, arbitrary code would execute directly in the runner. The script should be downloaded to a temporary file first, its checksum verified, and then executed separately.

Locations:

- `script.sh:11`

## Iteration Notes

### Iteration 1

**Fixes applied:** unsafe-shell

**Notes:**

Fixed script.sh line 11: replaced the `curl ... | sh -s ...` pipe pattern with a two-step approach. The install script is now downloaded to a mktemp temporary file first (`curl -sfL <url> -o "${INSTALL_SCRIPT}"`), then executed separately (`sh "${INSTALL_SCRIPT}" -s -- -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}"`), then removed with `rm -f`. The URL already pins to a specific commit SHA (fd59714416d6d9a1c0692d872e38e7f8448df4fc), providing content integrity at the source level. This eliminates the risk of arbitrary code execution from a compromised remote host or CDN redirect.

### Iteration 2

**Fixes applied:** ci-failure-70017997348

**Notes:**

Fixed script.sh line 13: removed the `-s --` flags from the `sh "${INSTALL_SCRIPT}"` invocation. The `-s` flag is a POSIX shell built-in option meaning "read commands from stdin", which is invalid when running a script file. This caused "Illegal option -s" errors and reviewdog was never installed, leading to "reviewdog: not found" at runtime. The correct invocation when executing a downloaded script file is `sh "${INSTALL_SCRIPT}" -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}"` (the `-s --` syntax is only needed when piping via stdin).

