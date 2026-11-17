<!-- markdownlint-disable -->

# Hardening Report: reviewdog--action-hadolint/v1.55.0

> This file was generated automatically by the hardening agent.

**Policy SHA:** `374911c4be584df24e6da57af2d990570ef0f859`

**Test Policy SHA:** `843adf9e4b8f85d0c08b27b9d0b09dd094b54702`

**Harden Agent Version:** `2`

Action **reviewdog--action-hadolint/v1.55.0** was hardened automatically. 4 finding(s) were identified and resolved across 1 iteration(s).

## Findings Fixed

### unsafe-shell (severity: high)

script.sh (the script run by the action's composite step) downloads the reviewdog installer with curl and pipes it straight into a shell: `curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/fd59714416d6d9a1c0692d872e38e7f8448df4fc/install.sh | sh -s -- -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}"`. The URL is pinned to a commit, but the content still runs without ever being saved and checked. Download it to a file first, verify it, then run it as a separate step.

Locations:

- `script.sh:11`

### script-injection (severity: high)

Rule (b): script.sh expands workflow-controlled input variables without quotes. The values come from inputs.* through env in action.yml. Affected lines: `for exclude_path in $INPUT_EXCLUDE; do` (line 28), `for include_path in $INPUT_INCLUDE; do` (line 34), `for rule in $INPUT_HADOLINT_IGNORE; do` (line 40), `git ls-files ${INCLUDES} --ignored --cached ${EXCLUDES}` (line 47), `xargs hadolint -f json ${INPUT_HADOLINT_FLAGS}` (line 48) and `${INPUT_REVIEWDOG_FLAGS}` (line 56). The file-level `# shellcheck disable=SC2086` hides these warnings. None of them are the exempt array-assignment form.

Locations:

- `script.sh:28`
- `script.sh:34`
- `script.sh:40`
- `script.sh:47`
- `script.sh:48`
- `script.sh:56`

### prior-fix (severity: high)

Carried forward from this version's previous harden, which fixed it; fix it again unless the code no longer has the problem. The previous harden changed action.yml without recording a finding for it, and this analysis reported nothing there. Re-apply its security changes unless the code no longer needs them. The previous patch:
```diff
diff --git a/action.yml b/action.yml
index 5eee977..df6ba40 100644
--- a/action.yml
+++ b/action.yml
@@ -1,5 +1,5 @@
 name: 'Run hadolint with reviewdog'
-description: '🐶 Run hadolint with reviewdog on pull requests to lint Dockerfile and validate inline bash.'
+description: "\U0001F436 Run hadolint with reviewdog on pull requests to lint Dockerfile and validate inline bash."
 author: 'mgrachev (reviewdog)'
 inputs:
   github_token:
@@ -52,6 +52,23 @@ inputs:
 runs:
   using: 'composite'
   steps:
     - run: $GITHUB_ACTION_PATH/script.sh
       shell: sh
       env:

```

Locations:

- `action.yml`

### prior-fix (severity: high)

Carried forward from this version's previous harden, which fixed it; fix it again unless the code no longer has the problem. The previous harden changed script.sh without recording a finding for it, and this analysis reported nothing there. Re-apply its security changes unless the code no longer needs them. The previous patch:
```diff
diff --git a/script.sh b/script.sh
index b4c2815..de3a306 100755
--- a/script.sh
+++ b/script.sh
@@ -1,14 +1,14 @@
 #!/bin/sh
 
-# shellcheck disable=SC2086,SC2089,SC2090
-
 cd "${GITHUB_WORKSPACE}" || exit
 
 TEMP_PATH="$(mktemp -d)"
 PATH="${TEMP_PATH}:$PATH"
 
 echo '::group::🐶 Installing reviewdog ... https://github.com/reviewdog/reviewdog'
-curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/fd59714416d6d9a1c0692d872e38e7f8448df4fc/install.sh | sh -s -- -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}" 2>&1
+INSTALL_SCRIPT="$(mktemp)"
+curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/fd59714416d6d9a1c0692d872e38e7f8448df4fc/install.sh -o "$INSTALL_SCRIPT"
+sh "$INSTALL_SCRIPT" -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}" 2>&1
 echo '::endgroup::'
 
 echo '::group:: Installing hadolint ... https://github.com/hadolint/hadolint'
@@ -18,34 +18,82 @@ if [ "$RUNNER_ARCH" = "ARM64" ]; then
   HADOLINT_FILE="hadolint-Linux-arm64"
 fi
 
-wget -q "https://github.com/hadolint/hadolint/releases/download/$HADOLINT_VERSION/$HADOLINT_FILE" -O $TEMP_PATH/hadolint \
-    && chmod +x $TEMP_PATH/hadolint
+wget -q "https://github.com/hadolint/hadolint/releases/download/$HADOLINT_VERSION/$HADOLINT_FILE" -O "$TEMP_PATH/hadolint" \
+    && chmod +x "$TEMP_PATH/hadolint"
 echo '::endgroup::'
 
 export REVIEWDOG_GITHUB_API_TOKEN="${INPUT_GITHUB_TOKEN}"
 
-EXCLUDES=""
-for exclude_path in $INPUT_EXCLUDE; do
-  set -- --exclude="!${exclude_path}"
-  EXCLUDES="$EXCLUDES $*"
-done
+# Build EXCLUDES: each token in INPUT_EXCLUDE becomes --exclude=!<token>
+# (INPUT_EXCLUDE is a whitespace-separated list of simple path tokens)
+set --
+if [ -n "$INPUT_EXCLUDE" ]; then
+  _tmpfile="$(mktemp)"
+  printf '%s' "$INPUT_EXCLUDE" | xargs -n1 printf '%s\n' > "$_tmpfile"
+  while IFS= read -r exclude_path; do
+    [ -n "$exclude_path" ] && set -- "$@" "--exclude=!${exclude_path}"
+  done < "$_tmpfile"
+  rm -f "$_tmpfile"
+fi
+EXCLUDES="$*"
 
-INCLUDES=""
-for include_path in $INPUT_INCLUDE; do
-  set -- --exclude="${include_path}"
-  INCLUDES="$INCLUDES $*"
-done
+# Build INCLUDES: each token in INPUT_INCLUDE becomes --exclude=<token>
+# (INPUT_INCLUDE is a whitespace-separated list of simple path tokens)
+set --
+if [ -n "$INPUT_INCLUDE" ]; then
+  _tmpfile="$(mktemp)"
+  printf '%s' "$INPUT_INCLUDE" | xargs -n1 printf '%s\n' > "$_tmpfile"
+  while IFS= read -r include_path; do
+    [ -n "$include_path" ] && set -- "$@" "--exclude=${include_path}"
+  done < "$_tmpfile"
+  rm -f "$_tmpfile"
+fi
+INCLUDES="$*"
 
-IGNORE_LIST=""
-for rule in $INPUT_HADOLINT_IGNORE; do
-  IGNORE_LIST="$IGNORE_LIST --ignore $rule"
-done
+# Build IGNORE_ARGS: each token in INPUT_HADOLINT_IGNORE becomes --ignore <token>
+# (INPUT_HADOLINT_IGNORE is a whitespace-separated list of rule names)
+set --
+if [ -n "$INPUT_HADOLINT_IGNORE" ]; then
+  _tmpfile="$(mktemp)"
+  printf '%s' "$INPUT_HADOLINT_IGNORE" | xargs -n1 printf '%s\n' > "$_tmpfile"
+  while IFS= read -r rule; do
+    [ -n "$rule" ] && set -- "$@" --ignore "$rule"
+  done < "$_tmpfile"
+  rm -f "$_tmpfile"
+fi
+IGNORE_ARGS="$*"
 
-INPUT_HADOLINT_FLAGS="$INPUT_HADOLINT_FLAGS $IGNORE_LIST"
+# Tokenize INPUT_HADOLINT_FLAGS (may contain quoted arguments) into positional params
+# then capture as a safe string for use in the pipeline
+set --
+if [ -n "$INPUT_HADOLINT_FLAGS" ]; then
+  _tmpfile="$(mktemp)"
+  printf '%s' "$INPUT_HADOLINT_FLAGS" | xargs -n1 printf '%s\n' > "$_tmpfile"
+  while IFS= read -r flag; do
+    [ -n "$flag" ] && set -- "$@" "$flag"
+  done < "$_tmpfile"
+  rm -f "$_tmpfile"
+fi
+HADOLINT_EXTRA_ARGS="$*"
+
+# Tokenize INPUT_REVIEWDOG_FLAGS (may contain quoted arguments) into positional params
+set --
+if [ -n "$INPUT_REVIEWDOG_FLAGS" ]; then
+  _tmpfile="$(mktemp)"
+  printf '%s' "$INPUT_REVIEWDOG_FLAGS" | xargs -n1 printf '%s\n' > "$_tmpfile"
+  while IFS= read -r flag; do
+    [ -n "$flag" ] && set -- "$@" "$flag"
+  done < "$_tmpfile"
+  rm -f "$_tmpfile"
+fi
+REVIEWDOG_EXTRA_ARGS="$*"
 
 echo '::group:: Running hadolint with reviewdog 🐶 ...'
-git ls-files ${INCLUDES} --ignored 
... (truncated)
```

Locations:

- `script.sh`

## Iteration Notes

### Iteration 1

**Fixes applied:** unsafe-shell, script-injection, prior-fix

**Notes:**

Fixed in script.sh: the reviewdog installer used to be piped straight from curl into sh. It is now saved to a file, checked to be non-empty and to start with a shebang, then run as `sh "$INSTALL_SCRIPT" -b "$TEMP_PATH" "$REVIEWDOG_VERSION"`. The `-s --` from the pipe form is dropped. This check is weak: there is no checksum, because I don't have a known-good hash for the pinned commit. The URL is still pinned to that commit.

Fixed the unquoted variables by switching the script's shebang to `#!/usr/bin/env bash`. This is a composite action on a GitHub runner, where bash is installed. Each list input (exclude, include, hadolint_ignore, hadolint_flags, reviewdog_flags) is now split with an unquoted array assignment, which splits on whitespace and expands globs the same way upstream's unquoted variables did. Every element is then passed as its own quoted argument ("${arr[@]}") to git ls-files, hadolint (via xargs, which still gets the file list on stdin) and reviewdog. Nothing in the values is evaluated. I removed the file-wide shellcheck disable and added one per line instead. I also quoted the hadolint download path.

Did not reuse the previous harden's `xargs -n1` approach: it honours quotes in the value and never expands globs, so it changes upstream's behaviour. For example, the default include `*Dockerfile*` is expanded as a glob upstream.

action.yml: put back the previous harden's change to the description (the emoji written as a \U0001F436 escape) and quoted the script path (`run: '"$GITHUB_ACTION_PATH/script.sh"'`).

Nothing was run or tested.

