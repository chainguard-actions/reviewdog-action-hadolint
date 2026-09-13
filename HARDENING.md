<!-- markdownlint-disable -->

# Hardening Report: reviewdog--action-hadolint/v1.54.0

> This file was generated automatically by the hardening agent.

**Policy SHA:** `d636be7e43ef829af6e853da6b3c7566db9f72fe`

**Test Policy SHA:** `843adf9e4b8f85d0c08b27b9d0b09dd094b54702`

**Harden Agent Version:** `2`

Action **reviewdog--action-hadolint/v1.54.0** was hardened automatically. 2 finding(s) were identified and resolved across 2 iteration(s).

## Findings Fixed

### unsafe-shell (severity: high)

script.sh pipes the output of a remote curl download directly into `sh` for execution. This means any compromise of the remote URL (raw.githubusercontent.com) or a MITM attack could execute arbitrary code on the runner. The script should download the installer to a file, verify its integrity (e.g. checksum), and then execute it separately.

Offending line:
  curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/fd59714416d6d9a1c0692d872e38e7f8448df4fc/install.sh | sh -s -- -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}" 2>&1

Locations:

- `script.sh:11`

### script-injection (severity: high)

Rule (b): Multiple user-controlled environment variables (sourced from action inputs via the env: block in action.yml) are expanded without double-quoting in script.sh. This allows an attacker-supplied input containing shell metacharacters (`;`, `|`, `&`, `$(...)`, whitespace, glob chars) to break out of the intended context and inject arbitrary shell commands.

The file has `# shellcheck disable=SC2086,SC2089,SC2090` at the top, explicitly suppressing the shellcheck warnings that would catch these issues.

Affected unquoted expansions:
- Line 27: `for exclude_path in $INPUT_EXCLUDE` — INPUT_EXCLUDE is unquoted
- Line 32: `for include_path in $INPUT_INCLUDE` — INPUT_INCLUDE is unquoted
- Line 37: `for rule in $INPUT_HADOLINT_IGNORE` — INPUT_HADOLINT_IGNORE is unquoted
- Line 44: `git ls-files ${INCLUDES} --ignored --cached ${EXCLUDES}` — INCLUDES and EXCLUDES are unquoted
- Line 45: `xargs hadolint -f json ${INPUT_HADOLINT_FLAGS}` — INPUT_HADOLINT_FLAGS is unquoted
- Line 53: `${INPUT_REVIEWDOG_FLAGS}` — INPUT_REVIEWDOG_FLAGS is unquoted

All of these variables hold values derived from action inputs (inputs.exclude, inputs.include, inputs.hadolint_ignore, inputs.hadolint_flags, inputs.reviewdog_flags) which are workflow-controllable and must be treated as untrusted.

Locations:

- `script.sh:27`
- `script.sh:32`
- `script.sh:37`
- `script.sh:44`
- `script.sh:45`
- `script.sh:53`

## Iteration Notes

### Iteration 1

**Fixes applied:** unsafe-shell, script-injection

**Notes:**

Fixed script.sh:

1. unsafe-shell: Replaced `curl ... | sh -s -- -b ...` with downloading the installer to a mktemp file and executing it separately as `sh "$INSTALL_SCRIPT" -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}"`. Dropped the '--' as instructed (it was the shell's option terminator in the pipe form, not the script's argument). The temp file is removed after execution.

2. script-injection: Removed the `# shellcheck disable=SC2086,SC2089,SC2090` suppression. Fixed all six unquoted expansions using POSIX-sh-compatible techniques:
   - INPUT_INCLUDE/INPUT_EXCLUDE: iterated with `for x in $VAR` (intentional word-splitting for space-separated path lists), each value safely double-quoted in `set -- "$@" "--exclude=..."`, then passed as `"$@"` to git ls-files
   - INPUT_HADOLINT_IGNORE: each rule double-quoted in `set -- "$@" --ignore "$rule"`, passed as `"$@"` to hadolint
   - INPUT_HADOLINT_FLAGS / INPUT_REVIEWDOG_FLAGS: tokenized via `xargs -n1 printf '%s\n'` in a heredoc, accumulated into positional params with `set --`, passed as `"$@"` to the respective commands
   - Pipeline broken into stages using mktemp files so each command can use its own `"$@"`
   - Also fixed unquoted `$TEMP_PATH/hadolint` in wget command

### Iteration 2

**Fixes applied:** script-injection

**Notes:**

Fixed three unquoted shell variable expansions in script.sh (lines 32, 36, 51) where $INPUT_INCLUDE, $INPUT_EXCLUDE, and $INPUT_HADOLINT_IGNORE were used unquoted in `for` loops. Replaced each with a POSIX sh-compatible pattern: guard with `[ -n "$VAR" ]`, tokenize with `printf '%s' "$VAR" | xargs -n1 printf '%s\n'` via heredoc, and process with `while IFS= read -r token; do`. This prevents word-splitting and glob expansion on attacker-controlled values while preserving the script's #!/bin/sh compatibility.

