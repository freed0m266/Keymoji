# Opt-in Welcome Plus trial

Tasks [63](../../tasks/63-monetization-keymoji-plus.md) (Done) and
[64](../../tasks/64-hesoyam-promo-trial.md) (Todo) both fix "no forced / app-implemented Plus trial" as
*Mimo scope* — the fear being that a blanket trial drops every user from ~20 favorites back to 6 after a
month → plošná loss-aversion → 1★ reviews → ztráta privacy/indie goodwill (jediné reálné aktivum).
HESOYAM was framed as the *opt-in* alternative to that rejection.

This decision adds an explicit **opt-in 30-day Plus trial**, offered as a gift in the onboarding
pick-favorites step and (until consumed) in Settings behind an explicit "Activate" CTA. It rehabilitates
the rejected app-implemented trial by **inheriting HESOYAM's single saving grace — self-selection** — so
the forced-trial fear doesn't apply: only users who explicitly accept the gift experience the post-trial
drop, and the existing downgrade safety net (favorites preserved over limit, loss-aversion banner in the
Favorites editor, Settings row returns to standard paywall) catches them. HESOYAM additionally gains a
+60-day grant that **stacks** onto the same `promoPlusExpiresAt` timeline
(`expiry = max(now, currentExpiry) + grantDays`); Welcome and HESOYAM remain independent one-shot grants
sharing one expiry. All entitlement gating sites (~5) migrate from the paid-only `AppGroupStore.isPlus`
to a unified `effectiveIsPlus(paid:, promoExpiresAt:, now:)` helper.

## Considered alternatives

- **Forced 30-day trial on install** (the original rejection target). Maximises endowment but restores
  the exact failure mode 63/64 cited — every user drops to the free tier after a month, including the
  ones who never opted in.
- **HESOYAM only, no Welcome trial.** Closer to original 64. Discoverability scales only with
  word-of-mouth of a public cheat — non-techy users never see that a free trial existed, and the cheat
  alone can't give Settings a permanent "try Plus free" entry point.

## Superseded / Update (2026-06-20)

The **HESOYAM cheat code half of this decision is removed** ([task 70](../../tasks/70-remove-hesoyam-cheat-code.md)). The opt-in **Welcome Plus trial stays exactly as decided above** — onboarding gift, Settings CTA, loss-aversion safety net, and the unified `effectiveIsPlus` gating are unchanged.

Why HESOYAM went:
- It never fired reliably on-device. `textDidChange` in a keyboard extension does not tick 1:1 with characters (the document buffer coalesces across suggestions), so the activation detection kept missing — see the revert log in [task 64](../../tasks/64-hesoyam-promo-trial.md) (first attempt reverted), and the device-tuned effect was never verified working.
- Acquisition is already fully covered by the Welcome trial, which works. HESOYAM carried only cost: a non-functional device path, `ConfettiSwiftUI` in the memory-sensitive extension, and a hidden-feature App Review 2.3.1 risk.

Consequences for the model: the **stacking rule is retired**. There is now a single one-shot grant (Welcome), so the *Plus trial expiry* is simply `now + 30d` at activation — no `max(now, currentExpiry) + grantDays`. `PromoTrialRecord` drops `cheatCodeConsumed`; the shared backbone (`PromoTrialStore`, `promoPlusExpiresAt`, Keychain, reconciliation, notifier) is otherwise untouched. Pre-release with no live grants, so there is no migration.
