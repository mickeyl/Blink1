#!/bin/bash
#
# Regenerates Blink1Bar.xcodeproj from project.yml.

set -euo pipefail
cd "$(dirname "$0")/.."

xcodegen generate
