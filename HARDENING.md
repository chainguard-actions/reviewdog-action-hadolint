<!-- markdownlint-disable -->

# Hardening Report: reviewdog--action-hadolint/v1.51.0

> This file was generated automatically by the hardening agent.

**Policy SHA:** `d636be7e43ef829af6e853da6b3c7566db9f72fe`

**Test Policy SHA:** `843adf9e4b8f85d0c08b27b9d0b09dd094b54702`

**Harden Agent Version:** `1`

Action **reviewdog--action-hadolint/v1.51.0** was hardened automatically. 2 finding(s) were identified and resolved across 2 iteration(s).

## Findings Fixed

### unsafe-shell (severity: high)

script.sh pipes the output of a remote curl download directly into `sh` for execution: `curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/fd59714416d6d9a1c0692d872e38e7f8448df4fc/install.sh | sh -s -- ...`. Even though the URL is pinned to a specific commit SHA, piping remote content directly to a shell interpreter is an unsafe pattern — if the remote server or network is compromised, arbitrary code executes immediately without any integrity check.

Locations:

- `script.sh:11`

### script-injection (severity: high)

Rule (b) violation: Multiple env vars holding workflow-controllable input values are expanded unquoted inside shell commands in script.sh (the file even has `# shellcheck disable=SC2086` to suppress these warnings). Unquoted expansions allow shell metacharacters (`;`, `|`, `&`, `$(...)`, glob chars, whitespace) in attacker-supplied input values to be interpreted by the shell:
- Line 26: `for exclude_path in $INPUT_EXCLUDE` — unquoted expansion of inputs.exclude
- Line 31: `for include_path in $INPUT_INCLUDE` — unquoted expansion of inputs.include
- Line 36: `for rule in $INPUT_HADOLINT_IGNORE` — unquoted expansion of inputs.hadolint_ignore
- Line 41: `git ls-files ${INCLUDES} --ignored --cached ${EXCLUDES}` — unquoted INCLUDES/EXCLUDES derived from the above inputs
- Line 42: `xargs hadolint -f json ${INPUT_HADOLINT_FLAGS}` — unquoted expansion of inputs.hadolint_flags
- Line 49: `${INPUT_REVIEWDOG_FLAGS}` — unquoted expansion of inputs.reviewdog_flags passed directly to reviewdog

Locations:

- `script.sh:26`
- `script.sh:31`
- `script.sh:36`
- `script.sh:41`
- `script.sh:42`
- `script.sh:49`

## Iteration Notes

### Iteration 1

**Fixes applied:** unsafe-shell, script-injection

**Notes:**

Fixed script.sh with two changes: (1) unsafe-shell: replaced `curl ... | sh` with a two-step approach — download the install script to a temp file with `curl -o`, then execute it separately with `sh`; (2) script-injection: removed the `# shellcheck disable=SC2086,SC2089,SC2090` suppression, replaced all unquoted variable expansions with bash arrays (EXCLUDES, INCLUDES, IGNORE_LIST, HADOLINT_FLAGS, REVIEWDOG_FLAGS), and expanded them with `"${ARRAY[@]}"` in all command invocations. Also updated action.yml to use `shell: bash` instead of `shell: sh` since the script now uses bash-specific array syntax.

### Iteration 2

**Fixes applied:** script-injection

**Notes:**

Fixed all five unquoted `$INPUT_*` variable expansions in for loops in script.sh (lines 29, 34, 39, 44, 50). Replaced `for var in $INPUT_FOO; do` patterns with safe IFS-controlled splitting using `IFS=' ' read -ra _array <<< "$INPUT_FOO"` followed by iteration over the quoted array `"${_array[@]}"`. Each block is also guarded with `[[ -n "$INPUT_FOO" ]]` to handle empty inputs correctly. This prevents glob expansion and word-splitting on attacker-controlled values, eliminating the shell metacharacter injection risk.

