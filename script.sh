#!/bin/sh

cd "${GITHUB_WORKSPACE}" || exit

TEMP_PATH="$(mktemp -d)"
PATH="${TEMP_PATH}:$PATH"

echo '::group::🐶 Installing reviewdog ... https://github.com/reviewdog/reviewdog'
INSTALL_SCRIPT="$(mktemp)"
curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/fd59714416d6d9a1c0692d872e38e7f8448df4fc/install.sh -o "$INSTALL_SCRIPT"
sh "$INSTALL_SCRIPT" -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}" 2>&1
rm -f "$INSTALL_SCRIPT"
echo '::endgroup::'

echo '::group:: Installing hadolint ... https://github.com/hadolint/hadolint'
HADOLINT_FILE="hadolint-Linux-x86_64"

if [ "$RUNNER_ARCH" = "ARM64" ]; then
  HADOLINT_FILE="hadolint-Linux-arm64"
fi

wget -q "https://github.com/hadolint/hadolint/releases/download/$HADOLINT_VERSION/$HADOLINT_FILE" -O "$TEMP_PATH/hadolint" \
    && chmod +x "$TEMP_PATH/hadolint"
echo '::endgroup::'

export REVIEWDOG_GITHUB_API_TOKEN="${INPUT_GITHUB_TOKEN}"

# Stage 1: git ls-files — build args from INPUT_INCLUDE and INPUT_EXCLUDE (space-separated lists)
# INPUT_INCLUDE entries become --exclude=<path> (git excludes non-matching files)
# INPUT_EXCLUDE entries become --exclude=!<path> (git un-excludes matching files)
set --
if [ -n "$INPUT_INCLUDE" ]; then
  while IFS= read -r include_path; do
    [ -n "$include_path" ] && set -- "$@" "--exclude=${include_path}"
  done <<_INCLUDE_EOF
$(printf '%s' "$INPUT_INCLUDE" | xargs -n1 printf '%s\n')
_INCLUDE_EOF
fi
set -- "$@" --ignored --cached
if [ -n "$INPUT_EXCLUDE" ]; then
  while IFS= read -r exclude_path; do
    [ -n "$exclude_path" ] && set -- "$@" "--exclude=!${exclude_path}"
  done <<_EXCLUDE_EOF
$(printf '%s' "$INPUT_EXCLUDE" | xargs -n1 printf '%s\n')
_EXCLUDE_EOF
fi
GIT_FILES_TMP="$(mktemp)"
git ls-files "$@" > "$GIT_FILES_TMP"

# Stage 2: hadolint — tokenize INPUT_HADOLINT_FLAGS, then append --ignore per rule
set --
if [ -n "$INPUT_HADOLINT_FLAGS" ]; then
  while IFS= read -r _tok; do
    [ -n "$_tok" ] && set -- "$@" "$_tok"
  done <<_HFLAGS_EOF
$(printf '%s\n' "$INPUT_HADOLINT_FLAGS" | xargs -n1 printf '%s\n')
_HFLAGS_EOF
fi
if [ -n "$INPUT_HADOLINT_IGNORE" ]; then
  while IFS= read -r rule; do
    [ -n "$rule" ] && set -- "$@" --ignore "$rule"
  done <<_IGNORE_EOF
$(printf '%s' "$INPUT_HADOLINT_IGNORE" | xargs -n1 printf '%s\n')
_IGNORE_EOF
fi
HADOLINT_OUT_TMP="$(mktemp)"
xargs hadolint -f json "$@" < "$GIT_FILES_TMP" > "$HADOLINT_OUT_TMP"
rm -f "$GIT_FILES_TMP"

# Stage 3: jq transform
RDJSON_TMP="$(mktemp)"
jq -f "${GITHUB_ACTION_PATH}/to-rdjson.jq" -c < "$HADOLINT_OUT_TMP" > "$RDJSON_TMP"
rm -f "$HADOLINT_OUT_TMP"

# Stage 4: reviewdog — tokenize INPUT_REVIEWDOG_FLAGS
set --
if [ -n "$INPUT_REVIEWDOG_FLAGS" ]; then
  while IFS= read -r _tok; do
    [ -n "$_tok" ] && set -- "$@" "$_tok"
  done <<_RFLAGS_EOF
$(printf '%s\n' "$INPUT_REVIEWDOG_FLAGS" | xargs -n1 printf '%s\n')
_RFLAGS_EOF
fi

echo '::group:: Running hadolint with reviewdog 🐶 ...'
reviewdog -f="rdjson" \
  -name="${INPUT_TOOL_NAME}" \
  -reporter="${INPUT_REPORTER}" \
  -filter-mode="${INPUT_FILTER_MODE}" \
  -fail-level="${INPUT_FAIL_LEVEL}" \
  -fail-on-error="${INPUT_FAIL_ON_ERROR}" \
  -level="${INPUT_LEVEL}" \
  "$@" < "$RDJSON_TMP"
EXIT_CODE=$?
rm -f "$RDJSON_TMP"
echo '::endgroup::'

exit $EXIT_CODE
