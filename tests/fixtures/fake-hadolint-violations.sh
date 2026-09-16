#!/bin/sh
# Fake hadolint - reports violations
echo '[{"line":1,"code":"DL3006","message":"Always tag the version of an image explicitly","column":1,"file":"Dockerfile","level":"warning"}]'
exit 0
