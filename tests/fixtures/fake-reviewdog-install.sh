#!/bin/sh
# Fake reviewdog installer script
# Usage: sh install.sh -b BINDIR VERSION
BINDIR=""
while [ $# -gt 0 ]; do
  case "$1" in
    -b)
      BINDIR="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
if [ -n "$BINDIR" ]; then
  printf '#!/bin/sh\ncat > /dev/null\nexit 0\n' > "$BINDIR/reviewdog"
  chmod +x "$BINDIR/reviewdog"
fi
