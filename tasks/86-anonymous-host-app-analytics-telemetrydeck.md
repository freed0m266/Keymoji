# 86 — Anonymní host-app analytics (TelemetryDeck) + privacy reconciliation

**Status:** Done — 2026-06-26 (TelemetryDeck SDK + host-only `Analytics` framework, opt-out toggle, privacy reconciliation; Codex P1 ×2 applied: SDK fully terminated on opt-out, placeholder App ID inert until set).

**Priorita:** v1.x (data pro produktová rozhodnutí; zavést před širším releasem) · **Úsilí:** L (SDK integrace + DI + opt-out toggle + přepis 5 míst privacy positioning + ADR) · **Dopad:** High (produktová data o cílovce **+ dotčení privacy positioningu** appky).

**Souvisí s:** [ADR 0004](../docs/adr/0004-anonymous-host-app-analytics.md) (rozhodnutí + trade-off), [63 — monetizace](63-monetization-keymoji-plus.md) (funnel signály). Dotýká se [`AppGroupStore`](../KeymojiCore/Sources/Shared/AppGroupStore.swift) (zdroj settings snímku), `KeymojiCore/Sources/Services` (DI, `AppDependency`), host app target ([`Project.swift`](../Project.swift) / Tuist), [`SettingsView`](../Features/Settings/Sources/SettingsView.swift) + VM, [`AboutView`](../Features/About/Sources/AboutView.swift) (privacy statement), `marketing/*`.

## Kontext / proč

Cíl: vědět, **jaké nastavení lidi reálně používají** a **kdo je cílovka**, aby šlo prioritizovat updaty. To nelze splnit on-device (vlastní zařízení = žádný signál) → vyžaduje anonymní agregát ven z telefonu. Appka má dnes **absolutní** privacy slib, který tomu odporuje:
- in-app: *„no network access, no analytics, and no third-party SDKs — nothing you type is ever sent off your iPhone"* ([Localizable.strings:180](../KeymojiResources/Resources/en.lproj/Localizable.strings))
- plánovaný App Store label **„Data Not Collected"**, promo **„zero tracking"** (memory *keymoji-app-store-connect*).

Rozhodnutí: slib se **zpřesní, nezboří** (viz ADR 0004). Načasování hraje pro nás — appka je `PREPARE_FOR_SUBMISSION`, ne veřejná, takže přepis je nejlevnější teď.

## Rozhodnutí (zafixovaná z této session)

| Téma | Rozhodnutí |
|---|---|
| **Nástroj** | **TelemetryDeck.** Swift-first, free 100k signálů/měs (~3 300 MAU), anonymizace double-hashingem na zařízení, GDPR by design, funnels/retention/dashboard ve free tieru, žádné ATT. (Aptabase byl zvažovaný open-source kandidát — zamítnut kvůli nižšímu free limitu + provozu serveru.) |
| **Hranice 1** | Telemetrii emituje **jen host app**. Keyboard extension SDK **neimportuje** a **nikdy nedělá síťový call** → „klávesnice nikdy nevolá domů" zůstává doslova pravda. |
| **Hranice 2** | **Nikdy žádný obsah** — žádné stisky, naučená slova, oblíbené emoji, hledané dotazy. Jen stavy nastavení + lifecycle. |
| **Hranice 3** | Jen **anonymně** — hashed anon ID, žádné PII/IDFA → žádný ATT prompt. |
| **Consent** | **Opt-out toggle** v Settings, **default ON**. OFF → emituje se **nula** signálů. |
| **Architektura** | Protokol `AnalyticsServicing` smí být v KeymojiCore (čistý, bez SDK). Konkrétní `TelemetryDeckAnalyticsService` **musí žít v host-app-only targetu** (Keymoji app, příp. nový `Analytics` framework linkovaný **jen** do appky) — KeymojiCore je linkovaný do extension (`APPLICATION_EXTENSION_API_ONLY = YES`), takže SDK do něj nesmí. DI přes `AppDependency` (host) + mock pro testy/preview. |

## Co trackovat

**A) Snímek nastavení** (jádro — „jaké nastavení lidi používají"), 1× při startu host appky, čtené z `AppGroupStore`:
appearance · letterLayout (qwerty/qwertz) · **letterAlternateSet (cs/sk/…/all ← jazyková cílovka)** · showNumberRow · hapticFeedbackEnabled · keyClickSoundEnabled · spaceDoubleTapAction · suggestionsEnabled · **autoCapitalizationEnabled** (task 85) · Plus stav (free/paid/trial) · stav analytics toggle.

**B) Lifecycle / funnel:** app spuštěna (retence — TelemetryDeck sám) · onboarding dokončen · paywall zobrazen · nákup / Welcome trial aktivován · **Review tlačítko ťuknuto** (task 83) · otevření pod-obrazovek Settings (About, Emoji codes, editor naučených slov, editor oblíbených).

**Buckety (ne přesně):** počet oblíbených (0 / 1–3 / 4–6 / 7+), počet naučených slov (pásmo).

## Privacy reconciliation (povinná součást scope)

- **In-app statement** [`about.privacyStatement`](../KeymojiResources/Resources/en.lproj/Localizable.strings): zachovat *„nothing you type is ever sent off your iPhone"*; *„no analytics"* → „anonymous usage statistics (opt-out, never content)"; *„no third-party SDKs"* vypustit / zpřesnit (TelemetryDeck SDK jen v host appce).
- **Privacy policy** [`marketing/privacy-policy.html`](../marketing/privacy-policy.html) (en + cs): disclose TelemetryDeck, co se sbírá (anonymní nastavení + lifecycle), opt-out, žádný obsah/PII; **re-upload** na hostovanou URL (`KeymojiURLs.privacyPolicy`).
- **App Store label**: „Data Not Collected" → **„Usage Data (Product Interaction) — Not Linked to You — Not Used for Tracking"**; promítnout do [`marketing/app-store/SUBMISSION.md`](../marketing/app-store/SUBMISSION.md) + ASC questionnaire.
- **Listing** [`listing-en.md`](../marketing/app-store/listing-en.md): promo *„zero tracking"* **zůstává** (TelemetryDeck netrackuje napříč appkami — Apple „tracking" = linkování s 3rd-party na reklamu); věty o „no analytics" zreconcilovat.
- **README** [non-goal řádek](README.md): analytics → in-scope (tento task); reklamy / crash reporting / tracking obsahu zůstávají non-goal.

## Scope (kód)

- `AnalyticsServicing` protokol (KeymojiCore) + `AnalyticsEvent` model (čistý, bez SDK).
- `TelemetryDeckAnalyticsService` v host-app-only targetu; init s App ID; respektuje opt-out flag.
- TelemetryDeck SDK přes SPM v Tuist — dependency **jen** na Keymoji app target (ověřit, že nepropadne do extension/KeymojiCore).
- Opt-out flag (host-side UserDefaults stačí — extension ho nečte; stav se ale posílá v A). Toggle v `SettingsView` (nová Privacy sekce nebo do supportSection) + VM + L10n + mock.
- Emise: settings snímek při `applicationDidBecomeActive` (host) + lifecycle hooky na příslušných místech (onboarding finish, paywall present, purchase, review tap, sub-screen navigation).

## Non-goals

- Analytics v keyboard extension; jakýkoli síťový call z extension.
- Jakýkoli obsah / keystroky / naučená slova / dotazy.
- Crash reporting, reklamy, cross-app tracking, ATT prompt, PII, IDFA.
- Per-uživatel identifikace (jen anonymní agregát).

## Akceptační kritéria

- Keyboard extension target **nelinkuje** TelemetryDeck (ověřit v Tuist deps / build).
- Opt-out OFF → **žádné** signály (ověřitelné mockem / dashboardem).
- Settings snímek se odešle anonymně při startu (A); event Review-tapped (B) přijde.
- Privacy statement + policy (en+cs) + App Store label + README zreconcilovány; [ADR 0004](../docs/adr/0004-anonymous-host-app-analytics.md) existuje.
- Žádný event neobsahuje text/obsah (code review hranice 2).

## Regresní síť

**Nové:** mock `AnalyticsServicing` v testech; test, že OFF → service neemituje; test mapování settings → event payloadu (jen povolené klíče, žádný obsah).

**Musí projít:** build extension targetu bez TelemetryDeck; stávající Settings/Onboarding/Paywall testy.

## Jak testovat (next session)

- Build přes **`Keymoji.xcworkspace`**, iPhone 17 / iOS 26.2. **Nové soubory** (protokol, service, model) → `tuist generate` **nutný** (memory *keymoji-tuist-new-files-silent-skip*).
- Ověřit deps grafu: extension nemá TelemetryDeck.
- Manuálně: po pár startech zkontrolovat TelemetryDeck dashboard (distribuce nastavení, funnel).
- **App Review pozn.:** label + policy musí sedět s reálným chováním před submitem (App ID 6776134522).
