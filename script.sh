#!/bin/bash

cd "${GITHUB_WORKSPACE}" || exit

TEMP_PATH="$(mktemp -d)"
PATH="${TEMP_PATH}:$PATH"

echo '::group::🐶 Installing reviewdog ... https://github.com/reviewdog/reviewdog'
REVIEWDOG_INSTALL_SCRIPT="${TEMP_PATH}/reviewdog-install.sh"
curl -sfL -o "${REVIEWDOG_INSTALL_SCRIPT}" https://raw.githubusercontent.com/reviewdog/reviewdog/fd59714416d6d9a1c0692d872e38e7f8448df4fc/install.sh
sh -n "${REVIEWDOG_INSTALL_SCRIPT}" || { echo "Downloaded install script failed shell syntax check"; exit 1; }
sh "${REVIEWDOG_INSTALL_SCRIPT}" -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}" 2>&1
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

# Build EXCLUDES array from INPUT_EXCLUDE (whitespace-separated list, quote-aware via xargs)
EXCLUDES=()
if [ -n "$INPUT_EXCLUDE" ]; then
  while IFS= read -r -d '' token; do
    EXCLUDES+=("--exclude=!${token}")
  done < <(printf '%s' "$INPUT_EXCLUDE" | xargs printf '%s\0')
fi

# Build INCLUDES array from INPUT_INCLUDE (whitespace-separated list, quote-aware via xargs)
INCLUDES=()
if [ -n "$INPUT_INCLUDE" ]; then
  while IFS= read -r -d '' token; do
    INCLUDES+=("--exclude=${token}")
  done < <(printf '%s' "$INPUT_INCLUDE" | xargs printf '%s\0')
fi

# Build IGNORE_LIST array from INPUT_HADOLINT_IGNORE (whitespace-separated list, quote-aware via xargs)
IGNORE_LIST=()
if [ -n "$INPUT_HADOLINT_IGNORE" ]; then
  while IFS= read -r -d '' token; do
    IGNORE_LIST+=(--ignore "$token")
  done < <(printf '%s' "$INPUT_HADOLINT_IGNORE" | xargs printf '%s\0')
fi

# Build HADOLINT_FLAGS array from INPUT_HADOLINT_FLAGS (whitespace-separated flags, quote-aware via xargs)
HADOLINT_FLAGS=()
if [ -n "$INPUT_HADOLINT_FLAGS" ]; then
  while IFS= read -r -d '' token; do
    HADOLINT_FLAGS+=("$token")
  done < <(printf '%s' "$INPUT_HADOLINT_FLAGS" | xargs printf '%s\0')
fi

# Build REVIEWDOG_FLAGS array from INPUT_REVIEWDOG_FLAGS (whitespace-separated flags, quote-aware via xargs)
REVIEWDOG_FLAGS=()
if [ -n "$INPUT_REVIEWDOG_FLAGS" ]; then
  while IFS= read -r -d '' token; do
    REVIEWDOG_FLAGS+=("$token")
  done < <(printf '%s' "$INPUT_REVIEWDOG_FLAGS" | xargs printf '%s\0')
fi

echo '::group:: Running hadolint with reviewdog 🐶 ...'
git ls-files "${INCLUDES[@]}" --ignored --cached "${EXCLUDES[@]}" \
  | xargs hadolint -f json "${IGNORE_LIST[@]}" "${HADOLINT_FLAGS[@]}" \
  | jq -f "${GITHUB_ACTION_PATH}/to-rdjson.jq" -c \
  | reviewdog -f="rdjson" \
    -name="${INPUT_TOOL_NAME}" \
    -reporter="${INPUT_REPORTER}" \
    -filter-mode="${INPUT_FILTER_MODE}" \
    -fail-level="${INPUT_FAIL_LEVEL}" \
    -fail-on-error="${INPUT_FAIL_ON_ERROR}" \
    -level="${INPUT_LEVEL}" \
    "${REVIEWDOG_FLAGS[@]}"
EXIT_CODE=$?
echo '::endgroup::'

exit $EXIT_CODE
