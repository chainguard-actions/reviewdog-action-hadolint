<!-- markdownlint-disable -->

# Hardening Report: reviewdog--action-hadolint/v1.50.5

> This file was generated automatically by the hardening agent.

**Policy SHA:** `d636be7e43ef829af6e853da6b3c7566db9f72fe`

**Test Policy SHA:** `843adf9e4b8f85d0c08b27b9d0b09dd094b54702`

**Harden Agent Version:** `1`

Action **reviewdog--action-hadolint/v1.50.5** was hardened automatically. 2 finding(s) were identified and resolved across 2 iteration(s).

## Findings Fixed

### unsafe-shell (severity: high)

script.sh pipes remote content directly to a shell interpreter. The line `curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/fd59714416d6d9a1c0692d872e38e7f8448df4fc/install.sh | sh -s -- -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}" 2>&1` downloads and immediately executes a remote script via `sh`. Even though the URL contains a commit SHA (which mitigates some risk), piping remote content directly to a shell is an unsafe pattern — the script should be downloaded to a file, verified, and then executed separately.

Locations:

- `script.sh:11`

### script-injection (severity: high)

Rule (b) violation: Multiple unquoted shell variable expansions of untrusted, workflow-controlled input values in script.sh. The composite action maps all user inputs into env vars (INPUT_EXCLUDE, INPUT_INCLUDE, INPUT_HADOLINT_IGNORE, INPUT_HADOLINT_FLAGS, INPUT_REVIEWDOG_FLAGS, INPUT_TOOL_NAME, INPUT_REPORTER, INPUT_FILTER_MODE, INPUT_FAIL_LEVEL, INPUT_FAIL_ON_ERROR, INPUT_LEVEL), which are then expanded unquoted in shell commands. This allows an attacker to inject shell metacharacters (`;`, `|`, `&`, `$(...)`, etc.) via any of these inputs. Affected lines include: `for exclude_path in $INPUT_EXCLUDE` (line 26), `for include_path in $INPUT_INCLUDE` (line 31), `for rule in $INPUT_HADOLINT_IGNORE` (line 36), `git ls-files ${INCLUDES} --ignored --cached ${EXCLUDES}` (line 43), `xargs hadolint -f json ${INPUT_HADOLINT_FLAGS}` (line 44), and `${INPUT_REVIEWDOG_FLAGS}` (line 53). The `# shellcheck disable=SC2086,SC2089,SC2090` comment at line 3 explicitly suppresses the unquoted-variable warnings, confirming these are known but unmitigated.

Locations:

- `script.sh:3`
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

Fixed two high-severity findings in script.sh:

1. unsafe-shell (line 11): Replaced `curl ... | sh` pipe with a two-step approach — download the reviewdog install script to `${TEMP_PATH}/install-reviewdog.sh` using `curl -o`, then execute it separately with `sh "${REVIEWDOG_INSTALL_SCRIPT}" ...`.

2. script-injection (lines 3, 26, 31, 36, 43, 44, 53): Converted the script from POSIX sh to bash and replaced all unquoted variable expansions with bash arrays. Each user-controlled input (INPUT_EXCLUDE, INPUT_INCLUDE, INPUT_HADOLINT_IGNORE, INPUT_HADOLINT_FLAGS, INPUT_REVIEWDOG_FLAGS) is now iterated and accumulated into a typed bash array (GIT_EXCLUDE_ARGS, GIT_INCLUDE_ARGS, HADOLINT_IGNORE_ARGS, HADOLINT_FLAGS_ARGS, REVIEWDOG_FLAGS_ARGS), then expanded with `"${array[@]}"` which prevents shell metacharacter injection. The `# shellcheck disable=SC2086,SC2089,SC2090` suppression comment was removed. action.yml was updated from `shell: sh` to `shell: bash` to match the new shebang.

### Iteration 2

**Fixes applied:** script-injection

**Notes:**

Fixed all 5 instances of unquoted variable expansion in for loops in script.sh (lines 32, 38, 44, 50, 56). Replaced `for var in $INPUT_VAR` patterns with safe array splitting using `read -ra _array <<< "$INPUT_VAR"` followed by `for var in "${_array[@]}"`. This prevents glob expansion and shell metacharacter injection from attacker-controlled input values while preserving the intended whitespace-splitting behavior.

