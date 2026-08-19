#!/bin/bash

cd "${GITHUB_WORKSPACE}" || exit

TEMP_PATH="$(mktemp -d)"
PATH="${TEMP_PATH}:$PATH"

echo '::group::🐶 Installing reviewdog ... https://github.com/reviewdog/reviewdog'
INSTALL_SCRIPT="$(mktemp)"
curl -sfL -o "${INSTALL_SCRIPT}" https://raw.githubusercontent.com/reviewdog/reviewdog/fd59714416d6d9a1c0692d872e38e7f8448df4fc/install.sh
sh "${INSTALL_SCRIPT}" -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}" 2>&1
rm -f "${INSTALL_SCRIPT}"
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

EXCLUDES=()
if [ -n "${INPUT_EXCLUDE}" ]; then
  read -ra _exclude_parts <<< "${INPUT_EXCLUDE}"
  for exclude_path in "${_exclude_parts[@]}"; do
    EXCLUDES+=("--exclude=!${exclude_path}")
  done
fi

INCLUDES=()
if [ -n "${INPUT_INCLUDE}" ]; then
  read -ra _include_parts <<< "${INPUT_INCLUDE}"
  for include_path in "${_include_parts[@]}"; do
    INCLUDES+=("--exclude=${include_path}")
  done
fi

IGNORE_LIST=()
if [ -n "${INPUT_HADOLINT_IGNORE}" ]; then
  read -ra _ignore_parts <<< "${INPUT_HADOLINT_IGNORE}"
  for rule in "${_ignore_parts[@]}"; do
    IGNORE_LIST+=(--ignore "$rule")
  done
fi

HADOLINT_FLAGS=()
if [ -n "${INPUT_HADOLINT_FLAGS}" ]; then
  read -ra HADOLINT_FLAGS <<< "${INPUT_HADOLINT_FLAGS}"
fi
HADOLINT_FLAGS+=("${IGNORE_LIST[@]}")

REVIEWDOG_FLAGS=()
if [ -n "${INPUT_REVIEWDOG_FLAGS}" ]; then
  read -ra REVIEWDOG_FLAGS <<< "${INPUT_REVIEWDOG_FLAGS}"
fi

echo '::group:: Running hadolint with reviewdog 🐶 ...'
git ls-files "${INCLUDES[@]}" --ignored --cached "${EXCLUDES[@]}" \
  | xargs hadolint -f json "${HADOLINT_FLAGS[@]}" \
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
