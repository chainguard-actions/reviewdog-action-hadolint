#!/usr/bin/env bash

cd "${GITHUB_WORKSPACE}" || exit

TEMP_PATH="$(mktemp -d)"
PATH="${TEMP_PATH}:$PATH"

echo '::group::🐶 Installing reviewdog ... https://github.com/reviewdog/reviewdog'
INSTALL_SCRIPT="${TEMP_PATH}/reviewdog-install.sh"
if ! curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/fd59714416d6d9a1c0692d872e38e7f8448df4fc/install.sh -o "${INSTALL_SCRIPT}"; then
  echo '::error::Failed to download reviewdog installer'
  exit 1
fi
if [ ! -s "${INSTALL_SCRIPT}" ] || ! head -n1 "${INSTALL_SCRIPT}" | grep -q '^#!'; then
  echo '::error::Downloaded reviewdog installer is empty or invalid'
  exit 1
fi
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

# The list inputs below are split (and globbed) exactly as upstream's unquoted
# expansions did, via unquoted array assignment; every resulting element is then
# passed as a separate, quoted argument. Nothing in the values is evaluated.

# shellcheck disable=SC2206
exclude_list=($INPUT_EXCLUDE)
excludes=()
for exclude_path in "${exclude_list[@]}"; do
  excludes+=("--exclude=!${exclude_path}")
done

# shellcheck disable=SC2206
include_list=($INPUT_INCLUDE)
includes=()
for include_path in "${include_list[@]}"; do
  includes+=("--exclude=${include_path}")
done

# shellcheck disable=SC2206
hadolint_args=($INPUT_HADOLINT_FLAGS)
# shellcheck disable=SC2206
ignore_list=($INPUT_HADOLINT_IGNORE)
for rule in "${ignore_list[@]}"; do
  hadolint_args+=(--ignore "$rule")
done

# shellcheck disable=SC2206
reviewdog_args=($INPUT_REVIEWDOG_FLAGS)

echo '::group:: Running hadolint with reviewdog 🐶 ...'
git ls-files "${includes[@]}" --ignored --cached "${excludes[@]}" \
  | xargs hadolint -f json "${hadolint_args[@]}" \
  | jq -f "${GITHUB_ACTION_PATH}/to-rdjson.jq" -c \
  | reviewdog -f="rdjson" \
    -name="${INPUT_TOOL_NAME}" \
    -reporter="${INPUT_REPORTER}" \
    -filter-mode="${INPUT_FILTER_MODE}" \
    -fail-level="${INPUT_FAIL_LEVEL}" \
    -fail-on-error="${INPUT_FAIL_ON_ERROR}" \
    -level="${INPUT_LEVEL}" \
    "${reviewdog_args[@]}"
EXIT_CODE=$?
echo '::endgroup::'

exit $EXIT_CODE
