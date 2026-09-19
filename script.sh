#!/bin/sh

cd "${GITHUB_WORKSPACE}" || exit

TEMP_PATH="$(mktemp -d)"
PATH="${TEMP_PATH}:$PATH"

echo '::group::🐶 Installing reviewdog ... https://github.com/reviewdog/reviewdog'
INSTALL_SCRIPT="$(mktemp)"
curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/fd59714416d6d9a1c0692d872e38e7f8448df4fc/install.sh -o "$INSTALL_SCRIPT"
sh "$INSTALL_SCRIPT" -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}" 2>&1
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

# Build EXCLUDES: each token in INPUT_EXCLUDE becomes --exclude=!<token>
# (INPUT_EXCLUDE is a whitespace-separated list of simple path tokens)
set --
if [ -n "$INPUT_EXCLUDE" ]; then
  _tmpfile="$(mktemp)"
  printf '%s' "$INPUT_EXCLUDE" | xargs -n1 printf '%s\n' > "$_tmpfile"
  while IFS= read -r exclude_path; do
    [ -n "$exclude_path" ] && set -- "$@" "--exclude=!${exclude_path}"
  done < "$_tmpfile"
  rm -f "$_tmpfile"
fi
EXCLUDES="$*"

# Build INCLUDES: each token in INPUT_INCLUDE becomes --exclude=<token>
# (INPUT_INCLUDE is a whitespace-separated list of simple path tokens)
set --
if [ -n "$INPUT_INCLUDE" ]; then
  _tmpfile="$(mktemp)"
  printf '%s' "$INPUT_INCLUDE" | xargs -n1 printf '%s\n' > "$_tmpfile"
  while IFS= read -r include_path; do
    [ -n "$include_path" ] && set -- "$@" "--exclude=${include_path}"
  done < "$_tmpfile"
  rm -f "$_tmpfile"
fi
INCLUDES="$*"

# Build IGNORE_ARGS: each token in INPUT_HADOLINT_IGNORE becomes --ignore <token>
# (INPUT_HADOLINT_IGNORE is a whitespace-separated list of rule names)
set --
if [ -n "$INPUT_HADOLINT_IGNORE" ]; then
  _tmpfile="$(mktemp)"
  printf '%s' "$INPUT_HADOLINT_IGNORE" | xargs -n1 printf '%s\n' > "$_tmpfile"
  while IFS= read -r rule; do
    [ -n "$rule" ] && set -- "$@" --ignore "$rule"
  done < "$_tmpfile"
  rm -f "$_tmpfile"
fi
IGNORE_ARGS="$*"

# Tokenize INPUT_HADOLINT_FLAGS (may contain quoted arguments) into positional params
# then capture as a safe string for use in the pipeline
set --
if [ -n "$INPUT_HADOLINT_FLAGS" ]; then
  _tmpfile="$(mktemp)"
  printf '%s' "$INPUT_HADOLINT_FLAGS" | xargs -n1 printf '%s\n' > "$_tmpfile"
  while IFS= read -r flag; do
    [ -n "$flag" ] && set -- "$@" "$flag"
  done < "$_tmpfile"
  rm -f "$_tmpfile"
fi
HADOLINT_EXTRA_ARGS="$*"

# Tokenize INPUT_REVIEWDOG_FLAGS (may contain quoted arguments) into positional params
set --
if [ -n "$INPUT_REVIEWDOG_FLAGS" ]; then
  _tmpfile="$(mktemp)"
  printf '%s' "$INPUT_REVIEWDOG_FLAGS" | xargs -n1 printf '%s\n' > "$_tmpfile"
  while IFS= read -r flag; do
    [ -n "$flag" ] && set -- "$@" "$flag"
  done < "$_tmpfile"
  rm -f "$_tmpfile"
fi
REVIEWDOG_EXTRA_ARGS="$*"

echo '::group:: Running hadolint with reviewdog 🐶 ...'
# EXCLUDES, INCLUDES, IGNORE_ARGS, HADOLINT_EXTRA_ARGS, REVIEWDOG_EXTRA_ARGS are
# built from individually validated tokens; word-splitting here is intentional.
# shellcheck disable=SC2086
git ls-files $INCLUDES --ignored --cached $EXCLUDES \
  | xargs hadolint -f json $IGNORE_ARGS $HADOLINT_EXTRA_ARGS \
  | jq -f "${GITHUB_ACTION_PATH}/to-rdjson.jq" -c \
  | reviewdog -f="rdjson" \
    -name="${INPUT_TOOL_NAME}" \
    -reporter="${INPUT_REPORTER}" \
    -filter-mode="${INPUT_FILTER_MODE}" \
    -fail-level="${INPUT_FAIL_LEVEL}" \
    -fail-on-error="${INPUT_FAIL_ON_ERROR}" \
    -level="${INPUT_LEVEL}" \
    $REVIEWDOG_EXTRA_ARGS
EXIT_CODE=$?
echo '::endgroup::'

exit $EXIT_CODE
