#!/bin/bash

cd "${GITHUB_WORKSPACE}" || exit

TEMP_PATH="$(mktemp -d)"
PATH="${TEMP_PATH}:$PATH"

echo '::group::🐶 Installing reviewdog ... https://github.com/reviewdog/reviewdog'
curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/fd59714416d6d9a1c0692d872e38e7f8448df4fc/install.sh -o "${TEMP_PATH}/install_reviewdog.sh"
sh "${TEMP_PATH}/install_reviewdog.sh" -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}" 2>&1
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
# INPUT_EXCLUDE is a space-separated list of paths
read -ra exclude_list <<< "$INPUT_EXCLUDE"
for exclude_path in "${exclude_list[@]}"; do
  EXCLUDES+=("--exclude=!${exclude_path}")
done

INCLUDES=()
# INPUT_INCLUDE is a space-separated list of paths
read -ra include_list <<< "$INPUT_INCLUDE"
for include_path in "${include_list[@]}"; do
  INCLUDES+=("--exclude=${include_path}")
done

IGNORE_FLAGS=()
# INPUT_HADOLINT_IGNORE is a space-separated list of rules
read -ra ignore_list <<< "$INPUT_HADOLINT_IGNORE"
for rule in "${ignore_list[@]}"; do
  IGNORE_FLAGS+=(--ignore "$rule")
done

# INPUT_HADOLINT_FLAGS is a space-separated list of flags
read -ra hadolint_flags <<< "$INPUT_HADOLINT_FLAGS"

# INPUT_REVIEWDOG_FLAGS is a space-separated list of flags
read -ra reviewdog_flags <<< "$INPUT_REVIEWDOG_FLAGS"

echo '::group:: Running hadolint with reviewdog 🐶 ...'
git ls-files "${INCLUDES[@]}" --ignored --cached "${EXCLUDES[@]}" \
  | xargs hadolint -f json "${hadolint_flags[@]}" "${IGNORE_FLAGS[@]}" \
  | jq -f "${GITHUB_ACTION_PATH}/to-rdjson.jq" -c \
  | reviewdog -f="rdjson" \
    -name="${INPUT_TOOL_NAME}" \
    -reporter="${INPUT_REPORTER}" \
    -filter-mode="${INPUT_FILTER_MODE}" \
    -fail-level="${INPUT_FAIL_LEVEL}" \
    -fail-on-error="${INPUT_FAIL_ON_ERROR}" \
    -level="${INPUT_LEVEL}" \
    "${reviewdog_flags[@]}"
EXIT_CODE=$?
echo '::endgroup::'

exit $EXIT_CODE
