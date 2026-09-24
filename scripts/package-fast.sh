#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/RightClickAssistantPro.xcodeproj"
SCHEME="${SCHEME:-RightClickAssistantPro}"
CONFIGURATION="${CONFIGURATION:-Release}"
DESTINATION="${DESTINATION:-platform=macOS}"
BUILD_ROOT="${BUILD_ROOT:-$ROOT_DIR/.build}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$BUILD_ROOT/DerivedData}"
SOURCE_PACKAGES_PATH="${SOURCE_PACKAGES_PATH:-$BUILD_ROOT/SourcePackages}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$BUILD_ROOT/$SCHEME.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$BUILD_ROOT/export}"
EXPORT_METHOD="${EXPORT_METHOD:-debugging}"
TEAM_ID="${TEAM_ID:-ATX6SQ3HRM}"
EXPORT_OPTIONS_PLIST="${EXPORT_OPTIONS_PLIST:-}"
BUILD_CODE_SIGNING_ALLOWED="${BUILD_CODE_SIGNING_ALLOWED:-NO}"

COMMON_ARGS=(
  -project "$PROJECT_PATH"
  -scheme "$SCHEME"
  -destination "$DESTINATION"
  -derivedDataPath "$DERIVED_DATA_PATH"
  -clonedSourcePackagesDirPath "$SOURCE_PACKAGES_PATH"
)

LOCKED_PACKAGE_ARGS=(
  -disableAutomaticPackageResolution
  -onlyUsePackageVersionsFromResolvedFile
  -skipPackageUpdates
)

usage() {
  cat <<'EOF'
Usage: scripts/package-fast.sh <command>

Commands:
  resolve   Resolve Swift packages once and reuse the local cache.
  build     Build with Package.resolved pinned and package updates disabled.
  archive   Archive with Package.resolved pinned and package updates disabled.
  export    Export the existing archive to a distributable app using xcodebuild.
  package   Run resolve, archive, and export in sequence.
  clean     Remove generated build/export artifacts while keeping Swift Package caches.

Optional environment variables:
  SCHEME=RightClickAssistantPro
  CONFIGURATION=Release
  DESTINATION='platform=macOS'
  BUILD_ROOT=/custom/build/root
  DERIVED_DATA_PATH=/custom/DerivedData
  SOURCE_PACKAGES_PATH=/custom/SourcePackages
  ARCHIVE_PATH=/custom/output/RightClickAssistantPro.xcarchive
  EXPORT_PATH=/custom/output/export
  EXPORT_METHOD=debugging
  TEAM_ID=YOUR_TEAM_ID
  EXPORT_OPTIONS_PLIST=/custom/ExportOptions.plist
  BUILD_CODE_SIGNING_ALLOWED=NO
EOF
}

resolve_packages() {
  mkdir -p "$BUILD_ROOT"
  xcodebuild \
    "${COMMON_ARGS[@]}" \
    -resolvePackageDependencies \
    -onlyUsePackageVersionsFromResolvedFile
}

build_project() {
  mkdir -p "$BUILD_ROOT"
  xcodebuild \
    "${COMMON_ARGS[@]}" \
    -configuration "$CONFIGURATION" \
    "${LOCKED_PACKAGE_ARGS[@]}" \
    CODE_SIGNING_ALLOWED="$BUILD_CODE_SIGNING_ALLOWED" \
    build
}

archive_project() {
  mkdir -p "$BUILD_ROOT"
  xcodebuild \
    "${COMMON_ARGS[@]}" \
    -configuration "$CONFIGURATION" \
    "${LOCKED_PACKAGE_ARGS[@]}" \
    -archivePath "$ARCHIVE_PATH" \
    archive

  "$ROOT_DIR/scripts/cleanup-archive-extension-registration.sh"
}

create_export_options_plist() {
  local plist_path="$1"

  cat > "$plist_path" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>${EXPORT_METHOD}</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>teamID</key>
  <string>${TEAM_ID}</string>
</dict>
</plist>
EOF
}

export_archive() {
  mkdir -p "$EXPORT_PATH"

  local plist_path
  if [[ -n "$EXPORT_OPTIONS_PLIST" ]]; then
    plist_path="$EXPORT_OPTIONS_PLIST"
  else
    plist_path="$BUILD_ROOT/ExportOptions-${EXPORT_METHOD}.plist"
    create_export_options_plist "$plist_path"
  fi

  xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$plist_path"
}

package_project() {
  resolve_packages
  archive_project
  export_archive
}

clean_cache() {
  rm -rf \
    "$BUILD_ROOT/dev-id-dmg" \
    "$BUILD_ROOT/export" \
    "$BUILD_ROOT/$SCHEME.xcarchive" \
    "$BUILD_ROOT/Build" \
    "$BUILD_ROOT/Logs" \
    "$BUILD_ROOT/Index.noindex" \
    "$BUILD_ROOT/ModuleCache.noindex" \
    "$DERIVED_DATA_PATH/Build" \
    "$DERIVED_DATA_PATH/Logs" \
    "$DERIVED_DATA_PATH/Index.noindex" \
    "$DERIVED_DATA_PATH/ModuleCache.noindex"

  if [[ -d "$BUILD_ROOT" ]]; then
    find "$BUILD_ROOT" \
      -maxdepth 1 \
      \( -name '*.dmg' -o -name '*.xcarchive' -o -name 'ExportOptions*.plist' \) \
      -exec rm -rf {} +
  fi
}

main() {
  local command="${1:-}"

  case "$command" in
    resolve)
      resolve_packages
      ;;
    build)
      build_project
      ;;
    archive)
      archive_project
      ;;
    export)
      export_archive
      ;;
    package)
      package_project
      ;;
    clean)
      clean_cache
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
