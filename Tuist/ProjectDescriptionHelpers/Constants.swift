import ProjectDescription

public let appGroupIdentifier = "group.com.freedommartin.keymoji"

/// Shared Keychain access group declared by both the host app and the keyboard extension so they can
/// read each other's promo-trial anti-abuse record. Uses `$(AppIdentifierPrefix)` (codesign team-prefixes
/// it at sign time) — no hardcoded team ID. The group name after the prefix must match
/// `promoKeychainGroupName` in KeymojiCore, which resolves the prefix at runtime.
public let keychainSharedAccessGroup = "$(AppIdentifierPrefix)com.freedommartin.keymoji.shared"
