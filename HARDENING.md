<!-- markdownlint-disable -->

# Hardening Report: reviewdog--action-hadolint/v1

> This file was generated automatically by the hardening agent.

**Policy SHA:** `d636be7e43ef829af6e853da6b3c7566db9f72fe`

**Test Policy SHA:** `843adf9e4b8f85d0c08b27b9d0b09dd094b54702`

**Harden Agent Version:** `2`

Action **reviewdog--action-hadolint/v1** was hardened automatically. 3 finding(s) were identified and resolved across 1 iteration(s).

## Findings Fixed

### unsafe-shell (severity: high)

script.sh pipes a remote install script directly to a shell interpreter: `curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/fd59714416d6d9a1c0692d872e38e7f8448df4fc/install.sh | sh -s -- -b ...`. Even though the URL is pinned to a specific commit SHA, piping remote content directly to `sh` is an unsafe pattern — the script should be downloaded to a file first, verified, and then executed separately.

Locations:

- `script.sh:11`

### script-injection (severity: high)

script.sh (invoked from action.yml) expands multiple env vars that are sourced from `inputs.*` values without double-quoting, violating rule (b). This allows an attacker to inject shell metacharacters (`;`, `|`, `&`, `$(...)`, glob chars, whitespace) via action inputs. Affected unquoted expansions:
- Line 26: `for exclude_path in $INPUT_EXCLUDE` — word-splits on INPUT_EXCLUDE (from inputs.exclude)
- Line 31: `for include_path in $INPUT_INCLUDE` — word-splits on INPUT_INCLUDE (from inputs.include)
- Line 36: `for rule in $INPUT_HADOLINT_IGNORE` — word-splits on INPUT_HADOLINT_IGNORE
- Line 43: `git ls-files ${INCLUDES} --ignored --cached ${EXCLUDES}` — unquoted composite vars
- Line 44: `xargs hadolint -f json ${INPUT_HADOLINT_FLAGS}` — unquoted flags from inputs
- Lines 47–52: `${INPUT_TOOL_NAME}`, `${INPUT_REPORTER}`, `${INPUT_FILTER_MODE}`, `${INPUT_FAIL_LEVEL}`, `${INPUT_FAIL_ON_ERROR}`, `${INPUT_LEVEL}`, `${INPUT_REVIEWDOG_FLAGS}` — all unquoted in the reviewdog command.
The file explicitly disables shellcheck SC2086 (unquoted variable warning) to suppress these warnings.

Locations:

- `script.sh:26`
- `script.sh:31`
- `script.sh:36`
- `script.sh:43`
- `script.sh:44`
- `script.sh:52`

### missing-permissions (severity: medium)

None of the 5 workflow files under .github/workflows/ define a `permissions:` key at the top level or at the job level. Without explicit permissions, workflows run with the default token permissions (which may include write access to repository contents, pull requests, etc.), violating the principle of least privilege. Affected files: depup.yml, release.yml, reviewdog.yml, test.yml, yamllint.yml.

Locations:

- `.github/workflows/depup.yml:1`
- `.github/workflows/release.yml:1`
- `.github/workflows/reviewdog.yml:1`
- `.github/workflows/test.yml:1`
- `.github/workflows/yamllint.yml:1`

## Iteration Notes

### Iteration 1

**Fixes applied:** unsafe-shell, script-injection, missing-permissions

**Notes:**

Fixed all three findings:

1. unsafe-shell: Replaced `curl ... | sh -s -- -b ...` with a two-step approach: download the reviewdog install script to a temp file with `curl -sfL ... -o "$INSTALL_SCRIPT"`, then execute it with `sh "$INSTALL_SCRIPT" -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}"`. The `--` was dropped (it was the shell's option terminator for the pipe form, not an argument to the install script).

2. script-injection: Restructured script.sh to use `set -- "$@" ...` to safely accumulate argument lists and `"$@"` to expand them. List inputs (INCLUDE, EXCLUDE, HADOLINT_IGNORE, HADOLINT_FLAGS, REVIEWDOG_FLAGS) are word-split intentionally via for loops but each token is added to positional params with proper quoting. Single-value inputs (TOOL_NAME, REPORTER, FILTER_MODE, FAIL_LEVEL, FAIL_ON_ERROR, LEVEL) are double-quoted. Removed the `# shellcheck disable=SC2086,SC2089,SC2090` suppression. Also fixed unquoted wget output path.

3. missing-permissions: Added `permissions:` blocks to all 5 workflow files with minimal required permissions: depup.yml (contents:write, pull-requests:write), release.yml (contents:write), reviewdog.yml (contents:read, pull-requests:write), test.yml (contents:read, checks:write, pull-requests:write), yamllint.yml (contents:read, pull-requests:write).

