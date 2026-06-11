#!/bin/sh

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

echo '::group:: Running hadolint with reviewdog 🐶 ...'

# Build git ls-files arguments.
# INPUT_INCLUDE and INPUT_EXCLUDE are space-separated lists; word-splitting is
# intentional so each token becomes one argument, then properly quoted via set --.
# Glob expansion is disabled (set -f) to prevent metacharacters in inputs from
# expanding to filenames.
set -f  # disable glob expansion to prevent metacharacter injection
set --
for include_path in $INPUT_INCLUDE; do
  set -- "$@" "--exclude=${include_path}"
done
for exclude_path in $INPUT_EXCLUDE; do
  set -- "$@" "--exclude=!${exclude_path}"
done
set +f  # re-enable glob expansion
# Collect matching Dockerfiles into a temp file
git ls-files "$@" --ignored --cached > "${TEMP_PATH}/dockerfiles.txt"

# Build hadolint arguments.
# INPUT_HADOLINT_FLAGS is a space-separated flag string; word-splitting is intentional.
# INPUT_HADOLINT_IGNORE is a space-separated list of rule names.
set -f  # disable glob expansion to prevent metacharacter injection
set --
for flag in $INPUT_HADOLINT_FLAGS; do
  set -- "$@" "$flag"
done
for rule in $INPUT_HADOLINT_IGNORE; do
  set -- "$@" --ignore "$rule"
done
set +f  # re-enable glob expansion
# Run hadolint on the collected files and convert output to rdjson
xargs hadolint -f json "$@" < "${TEMP_PATH}/dockerfiles.txt" \
  | jq -f "${GITHUB_ACTION_PATH}/to-rdjson.jq" -c \
  > "${TEMP_PATH}/rdjson.txt"

# Build reviewdog extra flags.
# INPUT_REVIEWDOG_FLAGS is a space-separated flag string; word-splitting is intentional.
set -f  # disable glob expansion to prevent metacharacter injection
set --
for flag in $INPUT_REVIEWDOG_FLAGS; do
  set -- "$@" "$flag"
done
set +f  # re-enable glob expansion
# Run reviewdog with properly quoted arguments
reviewdog -f="rdjson" \
  -name="${INPUT_TOOL_NAME}" \
  -reporter="${INPUT_REPORTER}" \
  -filter-mode="${INPUT_FILTER_MODE}" \
  -fail-level="${INPUT_FAIL_LEVEL}" \
  -fail-on-error="${INPUT_FAIL_ON_ERROR}" \
  -level="${INPUT_LEVEL}" \
  "$@" < "${TEMP_PATH}/rdjson.txt"
EXIT_CODE=$?
echo '::endgroup::'

exit $EXIT_CODE
