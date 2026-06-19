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
