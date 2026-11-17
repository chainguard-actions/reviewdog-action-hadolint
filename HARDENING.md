<!-- markdownlint-disable -->

# Hardening Report: reviewdog--action-hadolint/v1.56.0

> This file was generated automatically by the hardening agent.

**Policy SHA:** `374911c4be584df24e6da57af2d990570ef0f859`

**Test Policy SHA:** `843adf9e4b8f85d0c08b27b9d0b09dd094b54702`

**Harden Agent Version:** `2`

Action **reviewdog--action-hadolint/v1.56.0** was hardened automatically. 1 finding(s) were identified and resolved across 1 iteration(s).

## Findings Fixed

### unsafe-shell (severity: high)

script.sh, which the composite action's run step executes, pipes remote content straight into a shell: `curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/fd59714416d6d9a1c0692d872e38e7f8448df4fc/install.sh | sh -s -- -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}"`. The URL is pinned to a commit, but the downloaded script runs without being saved to a file or checked first. Download it to a file, verify its checksum, and then run it as a separate step.

Locations:

- `script.sh:11`

## Iteration Notes

### Iteration 1

**Fixes applied:** unsafe-shell

**Notes:**

script.sh: the reviewdog installer (still pinned to commit fd59714) is now saved to a file in TEMP_PATH instead of being piped into sh. The script stops if the download fails, if the file is empty, or if its first line isn't a '#!' interpreter line. The installer then runs as a separate command: 'sh "$file" -b "$TEMP_PATH" "$REVIEWDOG_VERSION"'. I dropped the '-s --' from the pipe form so the installer's $1 is still '-b'. The installer file is deleted after it runs. The finding asked for a checksum check, but I couldn't fetch the file to work out its real SHA-256, and I didn't want to make one up. So there is no checksum check. The only protection on the file's contents is that the URL points to a fixed commit. A follow-up could add a sha256sum check once someone has computed the real hash.

