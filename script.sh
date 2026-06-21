#!/bin/bash

cd "${GITHUB_WORKSPACE}" || exit

TEMP_PATH="$(mktemp -d)"
PATH="${TEMP_PATH}:$PATH"

echo '::group::🐶 Installing reviewdog ... https://github.com/reviewdog/reviewdog'
REVIEWDOG_INSTALL_SCRIPT="${TEMP_PATH}/install-reviewdog.sh"
curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/fd59714416d6d9a1c0692d872e38e7f8448df4fc/install.sh \
  -o "${REVIEWDOG_INSTALL_SCRIPT}"
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

EXCLUDES=()
if [[ -n "$INPUT_EXCLUDE" ]]; then
  IFS=' ' read -ra _exclude_paths <<< "$INPUT_EXCLUDE"
  for exclude_path in "${_exclude_paths[@]}"; do
    EXCLUDES+=("--exclude=!${exclude_path}")
  done
fi

INCLUDES=()
if [[ -n "$INPUT_INCLUDE" ]]; then
  IFS=' ' read -ra _include_paths <<< "$INPUT_INCLUDE"
  for include_path in "${_include_paths[@]}"; do
    INCLUDES+=("--exclude=${include_path}")
  done
fi

IGNORE_LIST=()
if [[ -n "$INPUT_HADOLINT_IGNORE" ]]; then
  IFS=' ' read -ra _rules <<< "$INPUT_HADOLINT_IGNORE"
  for rule in "${_rules[@]}"; do
    IGNORE_LIST+=(--ignore "$rule")
  done
fi

HADOLINT_FLAGS=()
if [[ -n "$INPUT_HADOLINT_FLAGS" ]]; then
  IFS=' ' read -ra _hadolint_flags <<< "$INPUT_HADOLINT_FLAGS"
  for flag in "${_hadolint_flags[@]}"; do
    HADOLINT_FLAGS+=("$flag")
  done
fi
HADOLINT_FLAGS+=("${IGNORE_LIST[@]}")

REVIEWDOG_FLAGS=()
if [[ -n "$INPUT_REVIEWDOG_FLAGS" ]]; then
  IFS=' ' read -ra _reviewdog_flags <<< "$INPUT_REVIEWDOG_FLAGS"
  for flag in "${_reviewdog_flags[@]}"; do
    REVIEWDOG_FLAGS+=("$flag")
  done
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
