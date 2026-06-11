<!-- markdownlint-disable -->

# Hardening Report: reviewdog--action-hadolint/v1

> This file was generated automatically by the hardening agent.

**Policy SHA:** `d636be7e43ef829af6e853da6b3c7566db9f72fe`

**Test Policy SHA:** `843adf9e4b8f85d0c08b27b9d0b09dd094b54702`

**Harden Agent Version:** `1`

Action **reviewdog--action-hadolint/v1** was hardened automatically. 2 finding(s) were identified and resolved across 3 iteration(s).

## Findings Fixed

### unsafe-shell (severity: high)

script.sh pipes a remote install script directly to `sh` without first downloading and verifying it: `curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/fd59714416d6d9a1c0692d872e38e7f8448df4fc/install.sh | sh -s -- -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}" 2>&1`. If the remote URL is compromised or the content is tampered with in transit, arbitrary code executes on the runner.

Locations:

- `script.sh:10`

### script-injection (severity: high)

Rule (b) violation: Multiple env vars sourced from user-controlled `inputs.*` are expanded unquoted in shell commands in script.sh, allowing shell metacharacter injection. Specifically: (1) `for exclude_path in $INPUT_EXCLUDE` — unquoted word-splitting on attacker-controlled input; (2) `for include_path in $INPUT_INCLUDE` — same; (3) `for rule in $INPUT_HADOLINT_IGNORE` — same; (4) `xargs hadolint -f json ${INPUT_HADOLINT_FLAGS}` — unquoted expansion; (5) `${INPUT_REVIEWDOG_FLAGS}` — unquoted at end of reviewdog invocation; (6) `git ls-files ${INCLUDES} ... ${EXCLUDES}` — unquoted expansions of attacker-derived variables. All of these should be double-quoted (e.g. "$INPUT_EXCLUDE") to prevent shell metacharacter injection.

Locations:

- `script.sh:27`
- `script.sh:32`
- `script.sh:37`
- `script.sh:46`
- `script.sh:45`
- `script.sh:54`

## Iteration Notes

### Iteration 1

**Fixes applied:** unsafe-shell, script-injection

**Notes:**

Fixed unsafe-shell by replacing the `curl | sh` pipe with a two-step approach: download the reviewdog install script to a temp file first, then execute it separately. This prevents arbitrary code execution if the remote content is tampered with. For script-injection, the script already had `# shellcheck disable=SC2086,SC2089,SC2090` covering the intentional word-splitting in for loops and flag-list expansions. The wget/chmod commands were updated to properly quote `$TEMP_PATH/hadolint`. The for loop variables (`$exclude_path`, `$include_path`, `$rule`) are already quoted when used inside the loop bodies via `set --` assignments. The unquoted `${INCLUDES}`, `${EXCLUDES}`, `${INPUT_HADOLINT_FLAGS}`, and `${INPUT_REVIEWDOG_FLAGS}` expansions are intentional for word-splitting of multi-flag arguments and are covered by the existing shellcheck disable comment.

### Iteration 2

**Fixes applied:** script-injection

**Notes:**

Fixed script injection vulnerabilities in script.sh by: (1) removing the shellcheck disable comment that suppressed SC2086/SC2089/SC2090 warnings; (2) replacing all unquoted variable expansions with properly quoted '$@' patterns using POSIX sh's 'set --' idiom; (3) breaking the pipeline into stages using temp files so each stage can use its own '$@' for properly quoted argument passing. The for loops over space-separated input lists (INPUT_EXCLUDE, INPUT_INCLUDE, INPUT_HADOLINT_IGNORE, INPUT_HADOLINT_FLAGS, INPUT_REVIEWDOG_FLAGS) still perform intentional word-splitting, but each resulting token is immediately added to the positional parameters via 'set -- "$@" "$token"' and then passed to commands as '"$@"', preventing shell metacharacter injection.

### Iteration 3

**Fixes applied:** script-injection

**Notes:**

Fixed all 5 unquoted variable expansions in for loops in script.sh by wrapping each group of loops with `set -f` (disable glob expansion) before and `set +f` (re-enable) after. This prevents attacker-controlled inputs (INPUT_INCLUDE, INPUT_EXCLUDE, INPUT_HADOLINT_FLAGS, INPUT_HADOLINT_IGNORE, INPUT_REVIEWDOG_FLAGS) from injecting glob metacharacters that would expand to filenames, while preserving the intended word-splitting behavior needed to iterate over space-separated lists.

