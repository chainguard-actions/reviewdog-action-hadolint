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

wget -q "https://github.com/hadolint/hadolint/releases/download/${HADOLINT_VERSION}/${HADOLINT_FILE}" -O "${TEMP_PATH}/hadolint" \
    && chmod +x "${TEMP_PATH}/hadolint"
echo '::endgroup::'

export REVIEWDOG_GITHUB_API_TOKEN="${INPUT_GITHUB_TOKEN}"

# Step 1: Collect Dockerfiles via git ls-files.
# INPUT_INCLUDE and INPUT_EXCLUDE are space-separated path lists; word-split is intentional.
set --
for include_path in $INPUT_INCLUDE; do
  set -- "$@" "--exclude=${include_path}"
done
set -- "$@" --ignored --cached
for exclude_path in $INPUT_EXCLUDE; do
  set -- "$@" "--exclude=!${exclude_path}"
done
DOCKERFILES_LIST="$(mktemp)"
git ls-files "$@" > "$DOCKERFILES_LIST"

# Step 2: Build hadolint argument list and run.
# INPUT_HADOLINT_IGNORE is a space-separated list of rule names; word-split is intentional.
set -- -f json
for rule in $INPUT_HADOLINT_IGNORE; do
  set -- "$@" --ignore "$rule"
done
# INPUT_HADOLINT_FLAGS is a space-separated flags list; word-split is intentional.
for flag in $INPUT_HADOLINT_FLAGS; do
  set -- "$@" "$flag"
done

HADOLINT_OUTPUT="$(mktemp)"
xargs hadolint "$@" < "$DOCKERFILES_LIST" > "$HADOLINT_OUTPUT" || true

echo '::group:: Running hadolint with reviewdog 🐶 ...'

# Step 3: Build reviewdog argument list and run.
# Single-value inputs are double-quoted. INPUT_REVIEWDOG_FLAGS is a flags list; word-split intentional.
set -- \
  -f="rdjson" \
  "-name=${INPUT_TOOL_NAME}" \
  "-reporter=${INPUT_REPORTER}" \
  "-filter-mode=${INPUT_FILTER_MODE}" \
  "-fail-level=${INPUT_FAIL_LEVEL}" \
  "-fail-on-error=${INPUT_FAIL_ON_ERROR}" \
  "-level=${INPUT_LEVEL}"
for flag in $INPUT_REVIEWDOG_FLAGS; do
  set -- "$@" "$flag"
done

jq -f "${GITHUB_ACTION_PATH}/to-rdjson.jq" -c < "$HADOLINT_OUTPUT" \
  | reviewdog "$@"
EXIT_CODE=$?
echo '::endgroup::'

exit $EXIT_CODE
