#!/usr/bin/env bash
#
# Upload the English App Store listing to App Store Connect via fastlane.
#
# Metadata only — no binary, no screenshots (see fastlane/Deliverfile) — and it
# never submits for review. The source of truth for the copy is
# marketing/app-store/listing-en.md, mirrored into fastlane/metadata/en-GB/.
# (The app's primary locale in ASC is en-GB, not en-US.)
#
# Requires:
#   - fastlane            -> brew install fastlane
#   - fastlane/.env       -> copy from fastlane/.env.example and fill in
#                            ASC_KEY_ID / ASC_ISSUER_ID / ASC_KEY_FILEPATH
#                            (App Store Connect API key; .env is gitignored)
#
# Usage:
#   scripts/upload_app_store_metadata.sh             # check lengths, then upload
#   scripts/upload_app_store_metadata.sh --verify    # read current ASC state back
#   scripts/upload_app_store_metadata.sh --skip-checks
#   scripts/upload_app_store_metadata.sh --help

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

verify=false
skip_checks=false

usage() {
    cat <<USAGE
Usage: $0 [--verify] [--skip-checks]

Uploads App Store metadata to App Store Connect via fastlane (lane
ios upload_metadata). Metadata only: no binary, no screenshots, no review
submission.

Options:
      --verify       Read the current listing back from ASC (lane inspect_app)
                     instead of uploading. Handy to confirm what is live.
      --skip-checks  Skip the check-lengths.sh character-limit verification.
  -h, --help         Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --verify) verify=true; shift ;;
        --skip-checks) skip_checks=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    esac
done

# fastlane is installed by Homebrew into its prefix; make sure that is on PATH
# even when this runs from a non-interactive shell.
if ! command -v fastlane >/dev/null 2>&1 && command -v brew >/dev/null 2>&1; then
    PATH="$(brew --prefix)/bin:${PATH}"
fi
if ! command -v fastlane >/dev/null 2>&1; then
    echo "error: fastlane not found. Install it with: brew install fastlane" >&2
    exit 1
fi

if [[ ! -f "${REPO_ROOT}/fastlane/.env" ]]; then
    echo "error: ${REPO_ROOT}/fastlane/.env not found." >&2
    echo "       Copy fastlane/.env.example to fastlane/.env and fill in the" >&2
    echo "       App Store Connect API key values." >&2
    exit 1
fi

# fastlane requires a UTF-8 locale (the listing copy uses em dashes etc.).
export LC_ALL="${LC_ALL:-en_US.UTF-8}"
export LANG="${LANG:-en_US.UTF-8}"

cd "${REPO_ROOT}"

if [[ "${verify}" == true ]]; then
    exec fastlane ios inspect_app
fi

if [[ "${skip_checks}" == false ]]; then
    echo "==> Verifying metadata character limits..."
    "${REPO_ROOT}/marketing/app-store/check-lengths.sh"
fi

echo "==> Uploading metadata to App Store Connect (no binary, no screenshots, no submit)..."
exec fastlane ios upload_metadata
