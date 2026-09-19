<!-- markdownlint-disable -->

# Hardening Report: reviewdog--action-hadolint/v1.55.0

> This file was generated automatically by the hardening agent.

**Policy SHA:** `d636be7e43ef829af6e853da6b3c7566db9f72fe`

**Test Policy SHA:** `843adf9e4b8f85d0c08b27b9d0b09dd094b54702`

**Harden Agent Version:** `2`

Action **reviewdog--action-hadolint/v1.55.0** was hardened automatically. 2 finding(s) were identified and resolved across 1 iteration(s).

## Findings Fixed

### unsafe-shell (severity: high)

script.sh pipes a remotely fetched install script directly to `sh` via curl: `curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/.../install.sh | sh -s -- ...`. Even though the URL contains a pinned commit SHA, piping remote content directly to a shell interpreter is an unsafe pattern — if the remote server or CDN is compromised, arbitrary code executes immediately on the runner without any integrity verification step.

Locations:

- `script.sh:11`

### script-injection (severity: high)

Multiple unquoted expansions of INPUT_* shell variables (sourced from action inputs via the env: block in action.yml) allow shell metacharacter injection (rule b). An attacker-controlled input value containing `;`, `|`, `&`, `$(...)`, or glob characters will be interpreted by the shell. The script even explicitly suppresses shellcheck warnings SC2086/SC2089/SC2090 for these patterns. Affected lines:
- Line 26: `for exclude_path in $INPUT_EXCLUDE` — unquoted word-split of inputs.exclude
- Line 31: `for include_path in $INPUT_INCLUDE` — unquoted word-split of inputs.include
- Line 36: `for rule in $INPUT_HADOLINT_IGNORE` — unquoted word-split of inputs.hadolint_ignore
- Line 43: `git ls-files ${INCLUDES} --ignored --cached ${EXCLUDES}` — unquoted expansion
- Line 44: `xargs hadolint -f json ${INPUT_HADOLINT_FLAGS}` — unquoted expansion of inputs.hadolint_flags
- Line 53: `${INPUT_REVIEWDOG_FLAGS}` — unquoted expansion of inputs.reviewdog_flags

Locations:

- `script.sh:26`
- `script.sh:31`
- `script.sh:36`
- `script.sh:43`
- `script.sh:44`
- `script.sh:53`

## Iteration Notes

### Iteration 1

**Fixes applied:** unsafe-shell, script-injection

**Notes:**

Fixed script.sh:

1. unsafe-shell: Replaced `curl ... | sh -s -- -b ...` with downloading the install script to a temp file (`curl ... -o "$INSTALL_SCRIPT"`) and then executing it separately (`sh "$INSTALL_SCRIPT" -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}"`). The `--` was correctly dropped — it was the shell's own option terminator in the pipe form, not an argument to the install script.

2. script-injection: All INPUT_* list variables are now safely tokenized using `xargs -n1 printf '%s\n'` piped through a temp file and read line-by-line with `while IFS= read -r`. This prevents shell metacharacters (`;`, `|`, `&`, `$(...)`, globs) in user-controlled inputs from being interpreted by the shell. The approach is POSIX sh compatible (no bash arrays needed). The original `# shellcheck disable=SC2086,SC2089,SC2090` suppression was removed. Also fixed unquoted `$TEMP_PATH/hadolint` in the wget command.

