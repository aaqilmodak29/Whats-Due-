#!/usr/bin/env bash
# Counts styles written inline instead of coming from lib/theme.dart: raw
# colour values and literal font sizes. Lower is more consistent.
cd "$(dirname "$0")/../.."
colours=$(grep -rnoE "Color\(0x[0-9A-Fa-f]{8}\)|Colors\.[a-z]+[A-Za-z]*(\[[0-9]+\]|\.shade[0-9]+)?" lib --include=*.dart | grep -v "^lib/theme.dart" | grep -v "Colors.transparent" | wc -l)
sizes=$(grep -rnoE "fontSize: *[0-9.]+" lib --include=*.dart | grep -v "^lib/theme.dart" | wc -l)
echo "{\"inline_colours\": $colours, \"inline_font_sizes\": $sizes, \"total\": $((colours + sizes))}"
