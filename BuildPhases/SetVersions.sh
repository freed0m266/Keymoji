#!/bin/sh
# ---------------------------------------------------------------------------
# Automatic Versioning Script
#
# Marketing Version (CFBundleShortVersionString):
#   Derived from a git tag in the "vX.Y.Z" format (e.g. v1.2.0 -> 1.2.0).
#   Archive builds require HEAD to be tagged, unless APP_MARKETING_VERSION is set.
#   Local non-archive builds fall back to the latest reachable tag or 0.1.0.
#
# Build Number (CFBundleVersion):
#   Derived from CI when possible, falling back to git commit count locally.
#   Override with APP_BUILD_NUMBER when needed.
# ---------------------------------------------------------------------------

set -eu

GENERIC_CI_BUILD_NUMBER="${BUILD_NUMBER:-}"

fail() {
	echo "error: $*" >&2
	exit 1
}

warn() {
	echo "warning: $*" >&2
}

info() {
	echo "info: $*"
}

is_marketing_version() {
	printf "%s" "$1" | grep -Eq '^(0|[1-9][0-9]*)[.](0|[1-9][0-9]*)[.](0|[1-9][0-9]*)$'
}

first_semver_tag() {
	git tag --points-at HEAD --list "v*" --sort=-v:refname 2>/dev/null | while IFS= read -r TAG; do
		VERSION="${TAG#v}"
		if is_marketing_version "$VERSION"; then
			printf "%s\n" "$TAG"
			break
		fi
	done
}

latest_reachable_semver_tag() {
	git tag --merged HEAD --list "v*" --sort=-v:refname 2>/dev/null | while IFS= read -r TAG; do
		VERSION="${TAG#v}"
		if is_marketing_version "$VERSION"; then
			printf "%s\n" "$TAG"
			break
		fi
	done
}

set_plist_value() {
	PLIST_PATH="$1"
	KEY="$2"
	VALUE="$3"

	if /usr/libexec/PlistBuddy -c "Print :$KEY" "$PLIST_PATH" >/dev/null 2>&1; then
		/usr/libexec/PlistBuddy -c "Set :$KEY $VALUE" "$PLIST_PATH"
	else
		/usr/libexec/PlistBuddy -c "Add :$KEY string $VALUE" "$PLIST_PATH"
	fi
}

update_plist_version() {
	PLIST_PATH="$1"

	set_plist_value "$PLIST_PATH" "CFBundleShortVersionString" "$MARKETING_VERSION"
	set_plist_value "$PLIST_PATH" "CFBundleVersion" "$BUILD_NUMBER"
	info "Updated $PLIST_PATH"
}

cd "${SRCROOT:?SRCROOT is not set}"

# --- Marketing Version ---
MARKETING_VERSION="${APP_MARKETING_VERSION:-}"

if [ -n "$MARKETING_VERSION" ]; then
	if ! is_marketing_version "$MARKETING_VERSION"; then
		fail "APP_MARKETING_VERSION must use X.Y.Z format, got '$MARKETING_VERSION'."
	fi
	info "Using APP_MARKETING_VERSION override."
else
	GIT_TAG=""

	if [ "${ACTION:-}" = "install" ] || [ "${REQUIRE_VERSION_TAG:-}" = "1" ]; then
		GIT_TAG=$(first_semver_tag)
		if [ -z "$GIT_TAG" ]; then
			fail "Archive builds require HEAD to be tagged as vX.Y.Z, or set APP_MARKETING_VERSION."
		fi
	else
		GIT_TAG=$(latest_reachable_semver_tag)
	fi

	if [ -n "$GIT_TAG" ]; then
		MARKETING_VERSION="${GIT_TAG#v}"
	else
		MARKETING_VERSION="0.1.0"
		warn "No reachable vX.Y.Z tag found, using default marketing version: $MARKETING_VERSION"
	fi
fi

# --- Build Number ---
BUILD_NUMBER="${APP_BUILD_NUMBER:-}"

if [ -z "$BUILD_NUMBER" ]; then
	BUILD_NUMBER="${CI_BUILD_NUMBER:-}"
fi

if [ -z "$BUILD_NUMBER" ]; then
	BUILD_NUMBER="${GITHUB_RUN_NUMBER:-}"
fi

if [ -z "$BUILD_NUMBER" ]; then
	BUILD_NUMBER="${BITRISE_BUILD_NUMBER:-}"
fi

if [ -z "$BUILD_NUMBER" ]; then
	BUILD_NUMBER="$GENERIC_CI_BUILD_NUMBER"
fi

if [ -z "$BUILD_NUMBER" ]; then
	BUILD_NUMBER="${CIRCLE_BUILD_NUM:-}"
fi

if [ -z "$BUILD_NUMBER" ]; then
	BUILD_NUMBER="${BUILDKITE_BUILD_NUMBER:-}"
fi

if [ -z "$BUILD_NUMBER" ]; then
	BUILD_NUMBER=$(git rev-list HEAD --count 2>/dev/null || date "+%y%j%H%M")
fi

if ! printf "%s" "$BUILD_NUMBER" | grep -Eq '^[0-9]+$'; then
	fail "Build number must contain digits only, got '$BUILD_NUMBER'."
fi

BUILD_NUMBER=$(printf "%s" "$BUILD_NUMBER" | sed 's/^0*//')

if [ -z "$BUILD_NUMBER" ] || [ "$BUILD_NUMBER" -le 0 ]; then
	fail "Build number must be greater than zero."
fi

info "Marketing Version (CFBundleShortVersionString): $MARKETING_VERSION"
info "Build Number (CFBundleVersion): $BUILD_NUMBER"

# --- Update the built target's Info.plist ---
if [ -z "${TARGET_BUILD_DIR:-}" ] || [ -z "${INFOPLIST_PATH:-}" ]; then
	fail "TARGET_BUILD_DIR and INFOPLIST_PATH must be set by Xcode."
fi

BUILT_PLIST="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"

if [ -f "$BUILT_PLIST" ]; then
	update_plist_version "$BUILT_PLIST"
else
	fail "Built Info.plist not found at $BUILT_PLIST"
fi
