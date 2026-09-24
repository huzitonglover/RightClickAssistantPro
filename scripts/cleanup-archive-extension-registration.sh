#!/bin/sh

set -eu

extension_bundle_id="${1:-rightPro.touch.com.ext}"

pluginkit_output="$(
  /usr/bin/pluginkit -m -A -D -v -i "$extension_bundle_id" -p com.apple.FinderSync 2>/dev/null || true
)"

printf '%s\n' "$pluginkit_output" \
| /usr/bin/awk -F '\t' '{print $NF}' \
| while IFS= read -r registered_path; do
    case "$registered_path" in
      *"/ArchiveIntermediates/"*"/InstallationBuildProductsLocation/"*"/AssistantFinderExtension.appex")
        /usr/bin/pluginkit -r "$registered_path" >/dev/null 2>&1 || true
        ;;
    esac
  done

/usr/bin/pluginkit -e use -p com.apple.FinderSync -i "$extension_bundle_id" >/dev/null 2>&1 || true
/usr/bin/killall Finder >/dev/null 2>&1 || true
