<!-- markdownlint-disable -->

# Hardening Report: reviewdog--action-hadolint/v1

> This file was generated automatically by the hardening agent.

**Policy SHA:** `374911c4be584df24e6da57af2d990570ef0f859`

**Test Policy SHA:** `843adf9e4b8f85d0c08b27b9d0b09dd094b54702`

**Harden Agent Version:** `2`

Action **reviewdog--action-hadolint/v1** was hardened automatically. 2 finding(s) were identified and resolved across 1 iteration(s).

## Findings Fixed

### unsafe-shell (severity: high)

script.sh, which the composite action's run step executes, downloads the reviewdog installer and pipes it straight into a shell: `curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/fd59714416d6d9a1c0692d872e38e7f8448df4fc/install.sh | sh -s -- -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}"`. The URL is pinned to a commit, but the downloaded content is never checked and runs immediately. Save the script to a file first (and ideally check its checksum), then run it as a separate step.

Locations:

- `script.sh:11`

### prior-fix (severity: high)

Carried forward from this version's previous harden, which fixed it; fix it again unless the code no longer has the problem. The previous harden changed script.sh without recording a finding for it, and this analysis reported nothing there. Re-apply its security changes unless the code no longer needs them. The previous patch:
```diff
diff --git a/script.sh b/script.sh
index b4c2815..37a3035 100755
--- a/script.sh
+++ b/script.sh
@@ -8,7 +8,10 @@ TEMP_PATH="$(mktemp -d)"
 PATH="${TEMP_PATH}:$PATH"
 
 echo '::group::🐶 Installing reviewdog ... https://github.com/reviewdog/reviewdog'
-curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/fd59714416d6d9a1c0692d872e38e7f8448df4fc/install.sh | sh -s -- -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}" 2>&1
+REVIEWDOG_INSTALL_SCRIPT="${TEMP_PATH}/reviewdog-install.sh"
+curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/fd59714416d6d9a1c0692d872e38e7f8448df4fc/install.sh -o "${REVIEWDOG_INSTALL_SCRIPT}" \
+  && sh "${REVIEWDOG_INSTALL_SCRIPT}" -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}" 2>&1
+rm -f "${REVIEWDOG_INSTALL_SCRIPT}"
 echo '::endgroup::'
 
 echo '::group:: Installing hadolint ... https://github.com/hadolint/hadolint'

```

Locations:

- `script.sh`

## Iteration Notes

### Iteration 1

**Fixes applied:** unsafe-shell, prior-fix

**Notes:**

script.sh no longer pipes the reviewdog installer into sh. It now downloads the script, which is still pinned to the same commit, into the temp dir and runs it as a file with `sh "$file" -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}"`. I dropped the `-s --`, so the installer's arguments are passed the same way as before. The file is deleted afterwards. This is the same change the earlier harden made. I did not add a checksum check on the downloaded installer, which the finding suggested as an extra step. Nothing was run to test the change.

