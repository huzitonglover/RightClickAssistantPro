#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_NAME="RightClickAssistantPro"
APP_BUNDLE_ID="rightPro.touch.com"
EXTENSION_BUNDLE_ID="rightPro.touch.com.ext"
APP_NAME="超级右键助手"
APP_NAMES=(
  "$APP_NAME"
  "超级右键专业版"
  "右键助手专业版"
  "右键工具专业版"
  "右键助手Pro"
  "RightMenu Pro"
  "Finder Menu Pro"
)
EXTENSION_NAME="AssistantFinderExtension"
APP_GROUP_ID="group.rightPro.touch.com"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

CLEAN_APP_STATE=0
CLEAN_INSTALLED_APPS=0
CLEAN_XCODE_ARCHIVES=0
CLEAN_QUIT_XCODE=0
CLEAN_RESTORE_EXTENSION=0

usage() {
  cat <<'EOF'
Usage: scripts/clean-local-test-env.sh [options]

Default cleanup:
  - Quit the app if it is running.
  - Disable and unregister FinderSync extension registrations.
  - Remove generated archives, exports, DMGs, and build products.
  - Unregister stale LaunchServices app and FinderSync extension records.
  - Unregister stale Xcode Archive, ArchiveIntermediates, /private/tmp, and renamed app records.
  - Keep Swift Package caches under .build/SourcePackages.
  - Remove Xcode DerivedData folders for RightClickAssistantPro.
  - Keep FinderSync disabled and restart extension services.

Options:
  --state           Also remove app containers, App Group data, and preferences.
  --installed-apps  Also remove installed app copies from /Applications and ~/Applications.
  --xcode-archives  Also remove Xcode Organizer archives named RightClickAssistantPro.
  --quit-xcode      Also quit Xcode before removing DerivedData, so it cannot immediately recreate index folders.
  --restore-extension
                    Re-enable FinderSync preference after cleanup.
  --all             Run full local test cleanup, except Swift Package caches.
  -h, --help        Show this help.
EOF
}

log() {
  printf '[clean] %s\n' "$*"
}

remove_path() {
  local path="$1"
  if [[ -e "$path" || -L "$path" ]]; then
    log "remove $path"
    rm -rf "$path"
  fi
}

unregister_launch_services_path() {
  local path="$1"
  [[ -n "$path" ]] || return
  log "unregister LaunchServices $path"
  "$LSREGISTER" -u "$path" >/dev/null 2>&1 || true
}

path_mentions_assistant() {
  local path="$1"
  local app_name

  case "$path" in
    *"$PROJECT_NAME"*|*"$APP_BUNDLE_ID"*|*"$EXTENSION_BUNDLE_ID"*|*"$EXTENSION_NAME"*)
      return 0
      ;;
  esac

  for app_name in "${APP_NAMES[@]}"; do
    [[ -n "$app_name" && "$path" == *"$app_name"* ]] && return 0
  done

  return 1
}

bundle_identifier_for_path() {
  local bundle_path="$1"
  local plist_path=""

  if [[ -f "$bundle_path/Contents/Info.plist" ]]; then
    plist_path="$bundle_path/Contents/Info.plist"
  elif [[ -f "$bundle_path/Info.plist" ]]; then
    plist_path="$bundle_path/Info.plist"
  fi

  [[ -n "$plist_path" ]] || return 0
  /usr/bin/plutil -extract CFBundleIdentifier raw -o - "$plist_path" 2>/dev/null || true
}

is_assistant_bundle() {
  local bundle_path="$1"
  local bundle_id

  case "$bundle_path" in
    *"$EXTENSION_NAME.appex")
      return 0
      ;;
  esac

  if path_mentions_assistant "$bundle_path"; then
    return 0
  fi

  bundle_id="$(bundle_identifier_for_path "$bundle_path")"
  [[ "$bundle_id" == "$APP_BUNDLE_ID" || "$bundle_id" == "$EXTENSION_BUNDLE_ID" ]]
}

unregister_parent_app_for_extension_path() {
  local extension_path="$1"
  local parent_app_path

  case "$extension_path" in
    */Contents/PlugIns/"$EXTENSION_NAME.appex")
      parent_app_path="${extension_path%/Contents/PlugIns/$EXTENSION_NAME.appex}"
      unregister_launch_services_path "$parent_app_path"
      ;;
  esac
}

quit_app() {
  /usr/bin/osascript -e "tell application id \"$APP_BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
  local app_name
  for app_name in "${APP_NAMES[@]}"; do
    /usr/bin/pkill -x "$app_name" >/dev/null 2>&1 || true
  done
}

unregister_finder_extension() {
  log "disable FinderSync extension $EXTENSION_BUNDLE_ID"
  /usr/bin/pluginkit -e ignore -p com.apple.FinderSync -i "$EXTENSION_BUNDLE_ID" >/dev/null 2>&1 || true

  local registrations
  registrations="$(
    /usr/bin/pluginkit -m -A -D -v -i "$EXTENSION_BUNDLE_ID" -p com.apple.FinderSync 2>/dev/null || true
  )"

  if [[ -z "$registrations" ]]; then
    return
  fi

  printf '%s\n' "$registrations" \
  | /usr/bin/awk -F '\t' 'NF {print $NF}' \
  | while IFS= read -r registered_path; do
      case "$registered_path" in
        *"$EXTENSION_NAME.appex")
          log "unregister $registered_path"
          /usr/bin/pluginkit -r "$registered_path" >/dev/null 2>&1 || true
          unregister_launch_services_path "$registered_path"
          unregister_parent_app_for_extension_path "$registered_path"
          ;;
      esac
    done
}

unregister_stale_launch_services_records() {
  local search_roots=(
    "$ROOT_DIR/.build"
    "$HOME/Library/Developer/Xcode/DerivedData"
    "$HOME/Library/Developer/Xcode/Archives"
    "$HOME/.Trash"
    "/private/tmp"
  )

  for search_root in "${search_roots[@]}"; do
    [[ -d "$search_root" ]] || continue

    while IFS= read -r -d '' bundle_path; do
        is_assistant_bundle "$bundle_path" || continue
        unregister_launch_services_path "$bundle_path"
      done < <(
        find "$search_root" \
          \( -name '*.app' -o -name "$EXTENSION_NAME.appex" \) \
          -print0 2>/dev/null || true
      )
  done

  unregister_stale_launch_services_dump_records
  rebuild_launch_services_if_needed
}

unregister_stale_launch_services_dump_records() {
  local line path

  while IFS= read -r line; do
    path="$(printf '%s\n' "$line" | sed -E 's/^[[:space:]]*path:[[:space:]]*//; s/[[:space:]]+\(0x[[:xdigit:]]+\)[[:space:]]*$//')"

    case "$path" in
      "$ROOT_DIR/.build/"*|"$HOME/Library/Developer/Xcode/DerivedData/"*|"$HOME/Library/Developer/Xcode/Archives/"*|"$HOME/.Trash/"*|"/private/tmp/"*|"/Volumes/"*)
        if path_mentions_assistant "$path"; then
          unregister_launch_services_path "$path"
        fi
        ;;
    esac
  done < <(
    "$LSREGISTER" -dump 2>/dev/null \
    | sed -n '/^[[:space:]]*path:[[:space:]]/p' || true
  )
}

launch_services_still_has_extension_records() {
  "$LSREGISTER" -dump 2>/dev/null \
  | /usr/bin/grep -E "$EXTENSION_BUNDLE_ID|$EXTENSION_NAME" >/dev/null 2>&1
}

rebuild_launch_services_if_needed() {
  "$LSREGISTER" -gc >/dev/null 2>&1 || true

  if launch_services_still_has_extension_records; then
    log "rebuild LaunchServices database"
    "$LSREGISTER" -kill -r -domain local -domain system -domain user >/dev/null 2>&1 || true
    "$LSREGISTER" -gc >/dev/null 2>&1 || true
  fi
}

restore_finder_extension_preference() {
  log "restore FinderSync extension preference $EXTENSION_BUNDLE_ID"
  /usr/bin/pluginkit -e use -p com.apple.FinderSync -i "$EXTENSION_BUNDLE_ID" >/dev/null 2>&1 || true
}

clean_build_outputs() {
  local app_name

  while IFS= read -r -d '' trashed_app_path; do
      is_assistant_bundle "$trashed_app_path" || continue
      unregister_launch_services_path "$trashed_app_path"
      remove_path "$trashed_app_path"
    done < <(
      find "$HOME/.Trash" \
        -maxdepth 1 \
        -type d \
        -name '*.app' \
        -print0 2>/dev/null || true
    )

  remove_path "$ROOT_DIR/.build/dev-id-dmg"
  remove_path "$ROOT_DIR/.build/export"
  remove_path "$ROOT_DIR/.build/$PROJECT_NAME.xcarchive"
  remove_path "$ROOT_DIR/.build/Build"
  remove_path "$ROOT_DIR/.build/Logs"
  remove_path "$ROOT_DIR/.build/Index.noindex"
  remove_path "$ROOT_DIR/.build/ModuleCache.noindex"
  remove_path "/private/tmp/rightclickassistant-derived"

  if [[ -d "$ROOT_DIR/.build" ]]; then
    while IFS= read -r -d '' build_artifact; do
        remove_path "$build_artifact"
      done < <(
        find "$ROOT_DIR/.build" \
          -maxdepth 1 \
          \( -name '*.dmg' -o -name '*.xcarchive' -o -name 'ExportOptions*.plist' \) \
          -print0 2>/dev/null || true
      )
  fi

  if [[ -d "$ROOT_DIR/.build/DerivedData" ]]; then
    while IFS= read -r -d '' derived_artifact; do
        remove_path "$derived_artifact"
      done < <(
        find "$ROOT_DIR/.build/DerivedData" \
          -maxdepth 1 \
          \( -name 'Build' -o -name 'Logs' -o -name 'Index.noindex' -o -name 'ModuleCache.noindex' \) \
          -print0 2>/dev/null || true
      )
  fi

  if [[ -d "$HOME/Library/Developer/Xcode/DerivedData" ]]; then
    while IFS= read -r -d '' derived_data_path; do
        unregister_stale_launch_services_records_under "$derived_data_path"
        remove_path "$derived_data_path"
      done < <(
        find "$HOME/Library/Developer/Xcode/DerivedData" \
          -maxdepth 1 \
          -type d \
          -name "$PROJECT_NAME-*" \
          -print0 2>/dev/null || true
      )
  fi
}

unregister_stale_launch_services_records_under() {
  local root="$1"
  [[ -d "$root" ]] || return

  while IFS= read -r -d '' bundle_path; do
      is_assistant_bundle "$bundle_path" || continue
      unregister_launch_services_path "$bundle_path"
    done < <(
      find "$root" \
        \( -name '*.app' -o -name "$EXTENSION_NAME.appex" \) \
        -print0 2>/dev/null || true
    )
}

clean_xcode_archives() {
  while IFS= read -r -d '' archive_path; do
      unregister_stale_launch_services_records_under "$archive_path"
      remove_path "$archive_path"
    done < <(
      find "$HOME/Library/Developer/Xcode/Archives" \
        -type d \
        \( -name "$PROJECT_NAME.xcarchive" -o -name "$PROJECT_NAME *.xcarchive" \) \
        -print0 2>/dev/null || true
    )
}

quit_xcode() {
  log "quit Xcode"
  /usr/bin/osascript -e 'tell application "Xcode" to quit' >/dev/null 2>&1 || true
}

clean_app_state() {
  log "remove local app state"
  remove_path "$HOME/Library/Group Containers/$APP_GROUP_ID"
  remove_path "$HOME/Library/Containers/$APP_BUNDLE_ID"
  remove_path "$HOME/Library/Containers/$EXTENSION_BUNDLE_ID"
  remove_path "$HOME/Library/Preferences/$APP_BUNDLE_ID.plist"
  remove_path "$HOME/Library/Preferences/$EXTENSION_BUNDLE_ID.plist"
  remove_path "$HOME/Library/Caches/$APP_BUNDLE_ID"
  remove_path "$HOME/Library/Caches/$EXTENSION_BUNDLE_ID"
}

clean_installed_apps() {
  local app_name
  for app_name in "${APP_NAMES[@]}"; do
    remove_path "/Applications/$app_name.app"
    remove_path "$HOME/Applications/$app_name.app"
  done
}

restart_extension_services() {
  /usr/bin/killall IsExtensionEnabled >/dev/null 2>&1 || true
  /usr/bin/killall pkd >/dev/null 2>&1 || true
  /usr/bin/killall Finder >/dev/null 2>&1 || true
}

verify_cleanup() {
  local registrations
  local extension_paths

  registrations="$(
    /usr/bin/pluginkit -m -A -D -v -i "$EXTENSION_BUNDLE_ID" -p com.apple.FinderSync 2>/dev/null || true
  )"
  if [[ -n "$registrations" && "$registrations" != "  (no matches)" ]]; then
    log "warning: FinderSync extension is still registered"
    printf '%s\n' "$registrations"
  fi

  extension_paths="$(
    find "$ROOT_DIR/.build" "$HOME/Library/Developer/Xcode/DerivedData" /private/tmp "$HOME/.Trash" \
      -path "*/$EXTENSION_NAME.appex" \
      -print 2>/dev/null || true
  )"
  if [[ -n "$extension_paths" ]]; then
    log "warning: extension files remain"
    printf '%s\n' "$extension_paths"
  fi

  if launch_services_still_has_extension_records; then
    log "warning: LaunchServices still has extension records"
    "$LSREGISTER" -dump 2>/dev/null \
    | /usr/bin/grep -E "$EXTENSION_BUNDLE_ID|$EXTENSION_NAME" || true
  fi
}

main() {
  while (($#)); do
    case "$1" in
      --state)
        CLEAN_APP_STATE=1
        ;;
      --installed-apps)
        CLEAN_INSTALLED_APPS=1
        ;;
      --xcode-archives)
        CLEAN_XCODE_ARCHIVES=1
        ;;
      --quit-xcode)
        CLEAN_QUIT_XCODE=1
        ;;
      --restore-extension)
        CLEAN_RESTORE_EXTENSION=1
        ;;
      --packages)
        log "ignore deprecated --packages; Swift Package caches are preserved"
        ;;
      --all)
        CLEAN_APP_STATE=1
        CLEAN_INSTALLED_APPS=1
        CLEAN_XCODE_ARCHIVES=1
        CLEAN_QUIT_XCODE=1
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        usage
        exit 1
        ;;
    esac
    shift
  done

  if [[ "$CLEAN_QUIT_XCODE" == "1" ]]; then
    quit_xcode
  fi

  quit_app
  unregister_finder_extension
  unregister_stale_launch_services_records
  clean_build_outputs
  unregister_stale_launch_services_records

  if [[ "$CLEAN_RESTORE_EXTENSION" == "1" ]]; then
    restore_finder_extension_preference
  fi

  if [[ "$CLEAN_XCODE_ARCHIVES" == "1" ]]; then
    clean_xcode_archives
    unregister_stale_launch_services_records
  fi

  if [[ "$CLEAN_APP_STATE" == "1" ]]; then
    clean_app_state
  fi

  if [[ "$CLEAN_INSTALLED_APPS" == "1" ]]; then
    clean_installed_apps
  fi

  restart_extension_services
  verify_cleanup
  log "done"
}

main "$@"
