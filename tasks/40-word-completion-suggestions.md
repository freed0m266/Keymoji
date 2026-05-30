# 40 — Word completion suggestions

**Status:** Done — 2026-05-29

**Priorita:** v1.2 · **Úsilí:** L · **Dopad:** High (daily-use feature, marketing differentiator přes privacy claim)

## Cíl

Přidat **prefix-match word completion** nad existujícím Slack suggestion bar: zatímco user píše slovo, bar nad klávesnicí nabízí 3 kandidáty na dokončení. Klepnutí na chip vloží zbytek slova + space. Bez autocorrect, bez fuzzy correction, bez nabízení překlepů.

Zdroje kandidátů (in priority): **(1)** osobní recents pool učený z user typing, **(2)** `UITextChecker.completions(...)` per active language, **(3)** `UILexicon` (Apple's system supplementary lexicon). Žádný internet, žádný bundlovaný korpus, žádný custom ML model.

Tento task revertuje původní rozhodnutí v [tasks/README.md](README.md) sekci „Mimo scope" — *„Word prediction / autocorrect je full project"* — pro tu část kterou Apple's vestavěná API přímo pokrývají (prefix completion). Plnohodnotná SwiftKey-style **next-word prediction** (bigram model nad personal corpus) zůstává out of scope; tahle architektura je ale postavená tak, aby ji bylo možné v budoucnu přidat jako další `SuggestionProvider` bez restrukturalizace.

## Kontext

- README.md doposud označoval prediction / autocorrect jako full project mimo scope. Důvod revize: **denní použitelnost** — chybí dokončování slov reálně bolí při dlouhých termínech, opakovaně psaných emailech, technické terminologii. Trigger pro tento task je usability, ne competitive positioning.
- Klíčový design constraint je **„language independent" v praktickém smyslu** = my nepíšeme per-jazykový kód a nebundlujeme korpusy. Apple's `UITextChecker` + `UILexicon` jsou per-language internally a iOS volí jazyk dle aktivního `documentInputMode.primaryLanguage`. Tím dostaneme English / Czech / cokoli zdarma. Personal recents pool je language-agnostic — jen Unicode string blob.
- Existuje vzor pro suggestion bar — [`SlackEmojiSuggester`](../KeyboardCore/Sources/Logic/SlackEmojiSuggester.swift) + [`SlackSuggestionBarView`](../KeyboardUI/Sources/Views/SlackSuggestionBarView.swift). Dnes bar nahrazuje number row když má obsah. Tento task **mění** vertikální layout (bar bude samostatný row nad case number row) a **refactoruje** Slack bar na generický `SuggestionBarView<Chip>` který současně hostuje plain-text word chips i pill emoji chips.
- `KeyboardViewController` orchestrate flow (state, dispatch, proxy, rebuild). Nový suggestion infra žije v `KeyboardCore` jako pure logic + `AppGroupStore` persistence.
- Personal recents jsou **PII-adjacent** (mohou obsahovat email addresses ze whitelist email fieldů, jména, slang). Persistence v `AppGroupStore` JSON, max 500 slov, manual clear v Settings. Privacy claim („nic neopouští zařízení") platí dál, ale potřebujeme explicit disclosure v privacy doc.

## Scope

### 1. Architektura — `SuggestionProviding` protocol + coordinator

V `KeyboardCore/Sources/Logic/Suggestions/` nový adresář s následujícím:

```swift
/// One ranked suggestion chip. Source-agnostic representation that the bar renders.
public struct Suggestion: Equatable, Sendable, Identifiable {
    public let id: String
    public let displayText: String          // co se zobrazí na chipu
    public let replacementText: String      // co se vloží při tapu (často == displayText)
    public let renderStyle: ChipRenderStyle // .plain (word) / .pill (slack)
    public let score: Double                 // [0..1], weighted merge ranking
    public let source: SuggestionSource     // .slack / .wordCompletion (debug + analytics future)
}

public enum ChipRenderStyle: Sendable { case plain, pill }
public enum SuggestionSource: Sendable { case slack, wordCompletion }

/// Pure async provider — given current document context, returns ranked candidates.
public protocol SuggestionProviding: Sendable {
    func suggestions(for context: SuggestionContext) -> [Suggestion]
}

public struct SuggestionContext: Sendable {
    public let documentContextBeforeInput: String?
    public let page: KeyboardPage
    public let primaryLanguage: String?       // z `UITextInputMode`, fallback "en"
    public let eligibility: SuggestionEligibility  // viz scope #4
}
```

`SuggestionCoordinator` mergeuje výstupy registered providers:

```swift
public struct SuggestionCoordinator: Sendable {
    public init(providers: [any SuggestionProviding], limit: Int = 3) { ... }

    /// 1) Pokud Slack provider vrátí non-empty → vrať ty (priority B: Slack wins).
    /// 2) Jinak collect ze všech non-Slack providerů, weighted merge, dedupe
    ///    case-insensitive (locale-aware), sort desc by score, top `limit`.
    /// 3) Pokud < `limit` → vrát kolik máme (F2 — hide empty slots).
    public func suggestions(for context: SuggestionContext) -> [Suggestion]
}
```

Existující `SlackEmojiSuggester` se zabalí do `SlackSuggestionProvider: SuggestionProviding` — produkuje `Suggestion` items s `renderStyle = .pill`, `score = 1.0` (Slack vždy vyhrává v rámci coordinator priority rule, score je ignored pokud je provider non-empty).

### 2. `WordCompletionProvider` — nový provider

V `KeyboardCore/Sources/Logic/Suggestions/WordCompletionProvider.swift`:

```swift
public struct WordCompletionProvider: SuggestionProviding {
    let textChecker: TextChecking           // protocol wrapper kolem UITextChecker, testable
    let systemLexicon: SystemLexiconProviding  // wrapper kolem UILexicon
    let recents: PersonalRecentsReading      // wrapper nad AppGroupStore, viz #3

    public func suggestions(for context: SuggestionContext) -> [Suggestion] {
        guard case .letters = context.page else { return [] }
        guard let prefix = activeWordPrefix(in: context.documentContextBeforeInput) else { return [] }
        guard !prefix.isEmpty else { return [] }
        guard !prefix.hasPrefix(":") else { return [] }  // Slack wins, gate

        let lang = context.primaryLanguage ?? "en"

        // Three sources, weighted merge:
        var candidates: [String: Double] = [:]

        // (a) Personal recents: 0.55 + 0.05 * min(count, 10) → [0.55, 1.0]
        for (word, count) in recents.matches(prefix: prefix) {
            let s = 0.55 + 0.05 * Double(min(count, 10))
            candidates[word] = max(candidates[word] ?? 0, s)
        }

        // (b) UITextChecker.completions: ordinal score 0.9 → 0.4 linearly
        let checkerHits = textChecker.completions(forPartialWord: prefix, language: lang)
        for (idx, word) in checkerHits.enumerated() {
            let s = 0.9 - (0.5 * Double(idx) / Double(max(checkerHits.count - 1, 1)))
            candidates[word] = max(candidates[word] ?? 0, s)
        }

        // (c) UILexicon: fixed 0.3
        for word in systemLexicon.entries(matchingPrefix: prefix) {
            candidates[word] = max(candidates[word] ?? 0, 0.3)
        }

        // Filter out self-match (prefix == candidate, user už napsal celé slovo)
        candidates[prefix] = nil
        candidates[prefix.lowercased()] = nil

        // Build Suggestion items with smart capitalization (CAP3)
        return candidates
            .map { word, score in
                let display = displayCapitalization(for: word, prefix: prefix, context: context)
                return Suggestion(
                    id: "word:\(display)",
                    displayText: display,
                    replacementText: display,
                    renderStyle: .plain,
                    score: score,
                    source: .wordCompletion
                )
            }
            .sorted { ($0.score, $1.displayText) > ($1.score, $0.displayText) }
    }
}
```

**Tokenization rules pro `activeWordPrefix(in:)`:**

- Walk backwards z konce contextu po word characters.
- Word character: Unicode letter, digit, apostrophe (`'`), Unicode combining marks (diakritika).
- Word boundary: whitespace, hyphen, comma, period, `:`, `;`, `?`, `!`, `(`, `)`, `[`, `]`, `{`, `}`, `/`, `\`, `@`, EOL, BOL.
- Stop at first non-word char nebo start of context.
- Mid-word detection: pokud `documentContextBeforeInput` končí word char A `documentContextAfterInput` začíná word char → user je uprostřed slova, vrať `nil` (bar collapse).

### 3. `PersonalRecentsStore` — learning + persistence

V `KeyboardCore/Sources/Storage/PersonalRecentsStore.swift`:

```swift
public struct PersonalRecentsStore: Sendable {
    public static let capacity = 500
    public static let minLength = 3       // LEN3 — user override
    public static let maxLength = 25      // standard filter — paste guard
    
    private let store: AppGroupStore

    /// Returns word → count for words whose case-insensitive form starts with `prefix`.
    public func matches(prefix: String) -> [(word: String, count: Int)]

    /// Append a learned word. Idempotent — duplicate words increment count.
    /// No-op if word fails filters (length, digit-only, alphanum-mix, max).
    /// Eviction: when at capacity, drop entry with lowest (count, recency) tuple.
    public mutating func learn(_ word: String, fromContextType: TextContextType)

    /// Total entries (for Settings counter).
    public var count: Int

    /// Wipes all entries.
    public mutating func clear()
}

public enum TextContextType: Sendable {
    case prose          // .default, .asciiCapable, nil
    case emailAddress   // keyboardType .emailAddress OR textContentType .emailAddress
    case denied         // everything else — no learning
}
```

**Storage formát:** JSON `{ "word": count, ... }` v `AppGroupStore` pod novým key `wordCompletionRecents`. Read = decode JSON na demand; write = encode + `setString` per learn-call (synchronní per word boundary, RW1).

**Filter rules (učení skip pokud):**
- `word.count < 3` nebo `word.count > 25`
- All-digit (`isCharacters.allSatisfy(\.isNumber)`)
- Mixed alphanum (obsahuje digit AND letter současně)
- `fromContextType == .denied`

**Email field special case (`fromContextType == .emailAddress`):**
- Whole field content je jeden token (žádný whitespace split). Učení proběhne při word boundary commit zachycení celého obsahu pole, ne per slovo. Implementace: `InputDispatcher` při dispatch space / punctuation v email fieldu **NEvolá** `learn(word:)` — místo toho se učení triggeruje při `textWillChange` nebo `viewWillDisappear` přečtením celého `documentContextBeforeInput` + `documentContextAfterInput` a uložením jako single token (pokud obsahuje `@` jako sanity check).

**Eviction algorithm:** udržujeme paralelní `[String: Date]` lastUsed mapa v UserDefaults. Při překročení 500: sort dle `(count ASC, lastUsed ASC)`, drop bottom 1. (Kombinovaný score zabraňuje aby super-staré-ale-časté slovo vyhodilo nedávno-jednou-použité.)

### 4. Eligibility — kde bar OFF a kde learning OFF

V `KeyboardCore/Sources/Logic/Suggestions/SuggestionEligibility.swift`:

```swift
public struct SuggestionEligibility: Sendable {
    public let allowDisplay: Bool   // smí se ukázat bar?
    public let learningContext: TextContextType  // .prose / .emailAddress / .denied

    public static func evaluate(
        isSecureTextEntry: Bool,
        keyboardType: UIKeyboardType,
        textContentType: UITextContentType?
    ) -> SuggestionEligibility
}
```

**Display deny rules (E1):**
- `isSecureTextEntry == true` → no display, no learning
- `textContentType ∈ {.password, .newPassword, .oneTimeCode, .creditCardNumber}` → no display, no learning
- `keyboardType ∈ {.numberPad, .decimalPad, .phonePad, .asciiCapableNumberPad, .URL, .webSearch, .twitter}` → no display, no learning
- `keyboardType == .emailAddress` OR `textContentType == .emailAddress` → **display ON**, learning context = `.emailAddress`
- `keyboardType ∈ {.namePhonePad}` → no display, no learning
- Default (`.default`, `.asciiCapable`, nebo nil) → display ON, learning context = `.prose`

**Learning whitelist (L2):**
- `.prose` → uloží do recents
- `.emailAddress` → uloží do recents (whole-field tokenization, viz #3)
- `.denied` → no learning ever

Caller (`KeyboardViewController`) evaluuje při každém `textDidChange` a předává do `SuggestionContext`.

### 5. UI — bar refactor + plain chip style

V [`KeyboardUI/Sources/Views/`](../KeyboardUI/Sources/Views/):

**a)** Refaktor `SlackSuggestionBarView` → generický `SuggestionBarView` který hostuje **arbitrary `[Suggestion]`** a renderuje per `renderStyle`:

```swift
public struct SuggestionBarView: View {
    let suggestions: [Suggestion]
    let onSelect: (Suggestion) -> Void

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(suggestions.indices, id: \.self) { idx in
                let s = suggestions[idx]
                Button(action: { onSelect(s) }) {
                    chip(for: s)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)

                if idx < suggestions.count - 1, s.renderStyle == .plain {
                    Divider().frame(height: 20)  // V2 — vertical dividers between plain chips
                }
            }
        }
        .frame(height: 40)
        // Background, padding, etc.
    }

    @ViewBuilder
    private func chip(for s: Suggestion) -> some View {
        switch s.renderStyle {
        case .plain:
            Text(s.displayText)
                .font(.body)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(.primary)
        case .pill:
            // existing Slack pill style: emoji + shortcode v pill background
            ...
        }
    }
}
```

**b)** `KeyboardView.swift` integrace — bar je teď **samostatný row nad case number row**, žádný mutex:

```swift
VStack(spacing: 0) {
    if showsSuggestionBar {
        SuggestionBarView(suggestions: suggestions, onSelect: onSelectSuggestion)
    }
    if layout.showsNumberRow {
        NumberRowView(...)
    }
    ForEach(layout.rows) { row in
        KeyboardRowView(row: row)
    }
}
```

`showsSuggestionBar` je `true` pokud:
- `state.suggestionsEnabled == true` (z `AppGroupStore`)
- `eligibility.allowDisplay == true`
- Page je `.letters` (na symbol/emoji pages bar neaktivní — match existing Slack behavior)

Bar zobrazený i když je `suggestions.isEmpty` (C1 — always-shown when enabled), tehdy je vizuálně tichý (empty body, background pořád vidět).

**c)** Animation: žádná (AN1). Chip swap = direct state mutation, žádný `withAnimation` wrap.

### 6. `KeyboardState` + `InputDispatcher` rozšíření

[`KeyboardState`](../KeyboardCore/Sources/Models/KeyboardState.swift) přidat:

```swift
public var suggestionsEnabled: Bool = true   // mirror AppGroupStore.suggestionsEnabled
public var currentEligibility: SuggestionEligibility = .denied
public var currentLanguage: String? = nil
```

[`InputDispatcher`](../KeyboardCore/Sources/Logic/InputDispatcher.swift) — nový synthesized key action:

```swift
public enum KeyAction {
    // ... existing cases
    case suggestionAccept(displayText: String, replacementText: String)
}
```

Handler v dispatcher:
1. Extrahuj current word prefix z `proxy.documentContextBeforeInput`
2. `for _ in 0..<prefix.count { proxy.deleteBackward() }`
3. `proxy.insertText(replacementText + " ")`
4. Per-char projet `ShiftStateMachine.apply(.characterInserted)` (SH3 — mirror manual typing)
5. Po insertu `refreshAutoCapitalization` (= textDidChange path bude triggernutý sám)

**Learning trigger v dispatcher:** po každé `KeyAction.space`, `.insertText(".")`, `.insertText(",")`, `.insertText("!")`, `.insertText("?")`:
1. Pokud `state.currentEligibility.learningContext == .prose`:
   - Extrahuj last word z `proxy.documentContextBeforeInput` (před právě-inserted boundary)
   - `recentsStore.learn(word, fromContextType: .prose)`
2. Pokud `.emailAddress`: skip (whole-field learning běží jinde — viz #3)

### 7. `KeyboardViewController` — drive Apple APIs + eligibility

V [`KeyboardViewController.swift`](../KeyboardExtension/Sources/KeyboardViewController.swift):

**a) Eager init v `viewDidLoad` (LX2):**

```swift
private lazy var textChecker = UITextChecker()
private var supplementaryLexicon: UILexicon?

override func viewDidLoad() {
    super.viewDidLoad()
    installHostingController()
    installSettingsObservers()
    requestSupplementaryLexicon { [weak self] lexicon in
        self?.supplementaryLexicon = lexicon
        self?.rebuild()
    }
}
```

**b) Eligibility re-eval na `textDidChange` + `viewWillAppear`:**

```swift
override func textDidChange(_ textInput: UITextInput?) {
    refreshReturnKeyType()
    refreshAutoCapitalization()
    refreshEligibility()
    refreshLanguage()
}

private func refreshEligibility() {
    let eligibility = SuggestionEligibility.evaluate(
        isSecureTextEntry: textDocumentProxy.isSecureTextEntry == true,
        keyboardType: textDocumentProxy.keyboardType ?? .default,
        textContentType: textDocumentProxy.textContentType
    )
    if state.currentEligibility != eligibility {
        state.currentEligibility = eligibility
        rebuild()
    }
}

private func refreshLanguage() {
    let lang = textInputMode?.primaryLanguage
    if state.currentLanguage != lang {
        state.currentLanguage = lang
        rebuild()
    }
}
```

**c) Suggestion compute v `makeRoot()`:**

Nahradit existující `currentSlackSuggestions()` voláním `SuggestionCoordinator.suggestions(for:)` s contextem postaveným z aktuálního state + proxy + lexicon. Coordinator interně řeší Slack-priority pravidlo.

**d) Email-field whole-field learning:**

V `viewWillDisappear` + `textWillChange` zkontrolovat: pokud `state.currentEligibility.learningContext == .emailAddress`, přečti `documentContextBeforeInput + documentContextAfterInput`, validuj že obsahuje `@`, ulož přes `recentsStore.learn(_:fromContextType: .emailAddress)`. Sanity guards: skip pokud > 100 znaků (pravděpodobně víc než email), skip pokud neobsahuje `@`.

### 8. `AppGroupStore` rozšíření + Darwin notification

V [`AppGroupStore.swift`](../KeyboCore/Sources/Shared/AppGroupStore.swift):

```swift
public extension AppGroupStore {
    var suggestionsEnabled: Bool {
        get { bool(forKey: .suggestionsEnabled, default: true) }
        set { setBool(newValue, forKey: .suggestionsEnabled) }
    }
    
    var wordCompletionRecentsJSON: String? {
        get { string(forKey: .wordCompletionRecents) }
        set { setString(newValue, forKey: .wordCompletionRecents) }
    }
}
```

V `AppGroupStoreKey.swift` přidat:
- `.suggestionsEnabled`
- `.wordCompletionRecents`

V `SettingsChangeNotifier` přidat:
- `.suggestionsEnabled` — keyboard extension subscribe pro live update

Extension observer:

```swift
settingsObservers.append(
    settingsNotifier.addObserver(for: .suggestionsEnabled) { [weak self] in
        self?.refreshFromStore()
    }
)
```

### 9. Settings UI — sekce „Suggestions"

V [`Features/Settings/Sources/SettingsView.swift`](../Features/Settings/Sources/SettingsView.swift) přidat novou Section pod typing-related sekcemi:

```swift
Section {
    Toggle(L10n.Settings.Suggestions.toggleTitle, isOn: $viewModel.suggestionsEnabled)
} header: {
    Text(L10n.Settings.Suggestions.sectionHeader)
} footer: {
    Text(L10n.Settings.Suggestions.toggleFooter)
        // "Suggests words as you type. Keybo learns from your typing to improve
        //  suggestions — all learning stays on this iPhone."
}

if viewModel.suggestionsEnabled {
    Section {
        HStack {
            Text(L10n.Settings.Suggestions.learnedWordsLabel)
            Spacer()
            Text("\(viewModel.learnedWordCount)")
                .foregroundStyle(.secondary)
        }
        Button(role: .destructive) {
            viewModel.confirmClearLearnedWords()
        } label: {
            Text(L10n.Settings.Suggestions.clearButton)
        }
    } footer: {
        Text(L10n.Settings.Suggestions.clearFooter)
        // "Removes all learned words. Apple's built-in suggestions are not affected."
    }
}
```

`SettingsViewModel` rozšířit o:
- `suggestionsEnabled: Bool` (bound to `AppGroupStore.suggestionsEnabled`)
- `learnedWordCount: Int` (read-only, refresh on view appear)
- `confirmClearLearnedWords()` → confirmation alert → `clear()` na recents store
- `clear()` mutates store + recomputes count + emits Darwin notification

### 10. Lokalizace

V [`KeyboResources/Resources/en.lproj/Localizable.strings`](../KeyboResources/Resources/en.lproj/Localizable.strings):

```strings
"settings.suggestions.section_header" = "Suggestions";
"settings.suggestions.toggle_title" = "Word suggestions";
"settings.suggestions.toggle_footer" = "Suggests words as you type. Keybo learns from your typing to improve suggestions — all learning stays on this iPhone.";
"settings.suggestions.learned_words_label" = "Learned words";
"settings.suggestions.clear_button" = "Clear learned words";
"settings.suggestions.clear_footer" = "Removes all learned words. Apple's built-in suggestions are not affected.";
"settings.suggestions.clear_alert_title" = "Clear learned words?";
"settings.suggestions.clear_alert_message" = "This permanently removes all words Keybo has learned from your typing. This cannot be undone.";
"settings.suggestions.clear_alert_confirm" = "Clear";

"onboarding.tour.suggestions.title" = "Private word suggestions";
"onboarding.tour.suggestions.description" = "Keybo suggests words as you type and learns from your typing — all on this iPhone. Nothing is sent online, not even to Apple. You can clear what Keybo has learned anytime in Settings.";
```

Po `tuist generate` se vygeneruje `L10n.Settings.Suggestions.*` + `L10n.Onboarding.Tour.Suggestions.*`. Použít.

### 11. Onboarding feature tour update (task 38)

V [`Features/Onboarding/Sources/FeatureHighlight.swift`](../Features/Onboarding/Sources/FeatureHighlight.swift) přidat do `FeatureHighlight.all`:

```swift
FeatureHighlight(
    id: "suggestions",
    symbol: "text.cursor",           // SF Symbol; alternativa: "wand.and.stars.inverse"
    title: L10n.Onboarding.Tour.Suggestions.title,
    description: L10n.Onboarding.Tour.Suggestions.description
)
```

Pořadí: zařadit jako **druhou položku** v tour (hned po diacritics), aby privacy angle byl visible early. Pokud po addění tour přesahuje 7 items hard cap z task 38, vyhodit nejméně-non-obvious item (kandidát: jeden z haptic/sound mergeu, pokud ho task 38 sloučil).

### 12. Privacy policy update

V [`marketing/privacy-policy.html`](../marketing/privacy-policy.html) přidat novou sekci před závěrečnou `Contact` sekcí:

```html
<h2>Word suggestions</h2>
<p>
  When you type, Keybo can suggest words to complete what you're writing.
  To make these suggestions better over time, Keybo remembers words you
  frequently type — words of 3 or more characters from regular text fields,
  plus email addresses you type in email-typed fields. This data is stored
  in a private container on your iPhone that only Keybo can read. It is
  never sent to any server, not even Apple's. You can remove all learned
  words anytime in Keybo → Settings → Suggestions → Clear learned words.
</p>
<p>
  Keybo never learns from:
</p>
<ul>
  <li>Password fields, secure text entry fields, or fields marked for one-time codes</li>
  <li>Credit card number fields</li>
  <li>Number pads, phone fields, or decimal pads</li>
  <li>URL bars or web search fields</li>
  <li>Name fields</li>
</ul>
<p>
  Word suggestions can be turned off entirely in Settings → Suggestions.
</p>
```

Rozšířit existující „What we don't do" / parallel claim sekci (pokud taková je) o explicitní zmínku že learning je local-only.

### 13. Testing

V `KeyboardCore/Tests/Suggestions/`:

**Unit testy:**
- `WordPrefixExtractorTests` — tokenization: apostrophe in, hyphen out, digit-only filtered, mid-word cursor returns nil, end-of-context boundary
- `PersonalRecentsStoreTests` — learn idempotence, count increment, capacity eviction order, filter rules (digit-only, mixed, length bounds), clear semantics
- `WordCompletionProviderTests` — weighted merge math, self-match exclusion, dedupe case-insensitive, prefix `:` gate
- `SuggestionCoordinatorTests` — Slack-priority short circuit, fallback merging, limit enforcement
- `SuggestionEligibilityTests` — every (keyboardType × textContentType × isSecureTextEntry) → expected (allowDisplay, learningContext)

Mock providers + mock `TextChecking` / `SystemLexiconProviding` v `KeyboardCore/Testing/` (existing `Testing/` adresář vzor).

**Snapshot testy** v `KeyboardUI/Tests/`:
- `SuggestionBarView` s 3 plain chips (typical)
- `SuggestionBarView` s 1 plain chip (sparse F2)
- `SuggestionBarView` empty (always-on, no chips C1)
- `SuggestionBarView` s 3 pill chips (Slack regression check)
- Dark + light variants pro každý
- iPhone SE width pro long-word overflow (`martin.svoboda026@gmail.com`)

**Integration smoke:**
- `KeyboardViewController` snapshot s bar zobrazený (mock state)
- Číselný row + bar coexistence (oba zapnuté → dva rows nad keys)

### 14. Build verification + manual test plan

Po implementaci:
1. `mise exec -- tuist generate` (nebo project-specific build command)
2. Build keyboard extension target
3. Manual test scénáře (krycí matrix):
   - Letter page, prose field, prefix `hel` → bar shows 3 completions
   - Letter page, prose field, mid-word cursor → bar collapses
   - Letter page, prose field, `:smi` → Slack provider wins, pill chips
   - Letter page, password field → bar hidden
   - Letter page, email field, prefix `mar` → email chip `martin.svoboda...@...com` appears if previously typed
   - Symbol page → bar collapsed regardless of state
   - Settings → toggle off → bar disappears immediately (Darwin notification)
   - Settings → clear → bar empties of personal items, lexicon still works
   - Cold start (kill extension, reopen) → bar usable within ~50 ms of first keypress

### 15. README.md dual update

V [tasks/README.md](README.md):

**a) Přidat sekci `## v1.2` nad `## Pre-App-Store`:**

```markdown
## v1.2 — Word suggestions

40. [40 — Word completion suggestions (UILexicon + UITextChecker + personal recents)](40-word-completion-suggestions.md)
```

**b) Upravit „Mimo scope úplně" entry:**

Původní:
```
- **Word prediction / autocorrect.** SwiftKey-style ML prediction je full project. Mimo Keybo scope.
```

Nahradit dvěma entries:
```
- **SwiftKey-style next-word prediction (bigram model nad personal corpus).**
  Prefix-match completion z UILexicon + UITextChecker + personal recents je
  v scope (v1.2, task 40). Plnotučná next-word prediction (predikce dalšího
  slova bez prefixu) zůstává out of scope.
- **Autocorrect.** Bar nikdy nenabízí překlepy a nikdy ticho nepřepisuje text
  po space. Selection je vždy explicitní (tap na chip). Out of scope permanentně.
```

README update jde do stejného PR/commit chain jako task 40 implementace.

## Mimo scope

- **Next-word prediction (bigram nad personal corpus).** Architektura je připravena (`SuggestionProviding` protocol je source-agnostic, lze přidat `NextWordPredictionProvider`), ale samotná implementace je future task. Cílí v1.3+.
- **Autocorrect / silent text replacement po space.** Bar nikdy automaticky nepřepisuje user input. Selection je vždy explicitní (tap na chip). Permanently out of scope per design rule.
- **Fuzzy / spell-correction suggestions.** `UITextChecker.guesses(...)` se nikdy nepoužije, jen `.completions(...)`. User který napíše `helo` dostane buď completion `helot` nebo nic — nikdy `hello` jako „opravu".
- **Spell-check podtrhnout červeně.** Mimo scope — Keybo není editor, je klávesnice.
- **Per-app deny-list** („v Signalu nelearn"). Hypotetický future task pokud uživatelé reportují privacy concern. Default deny-list per field type (E1) by měl 99 % case pokrýt.
- **Per-word management list** v Settings („here are 500 learned words, swipe to delete"). Shoulder-surfing risk + UI bloat. Pouze bulk clear button.
- **Granular learning toggle** (separate od display). Jeden master toggle stačí.
- **Decay over time** (timestamp-based pruning). LRU eviction nad cap 500 je dostatečná pro v1.2.
- **Cloud sync recents přes iCloud.** Out of scope; design je intentionally device-local.
- **Predictive emoji (🙂 jako chip pro `happy`).** Out of scope, separátní future task.
- **iPad layout adaptation.** Per README.md, iPad obecně mimo Keybo scope.

## Hotovo když

- [ ] `SuggestionProviding` protocol + `SuggestionCoordinator` + `Suggestion` model existují v `KeyboardCore/Sources/Logic/Suggestions/`
- [ ] `WordCompletionProvider` implementuje weighted merge ranking (R2) přes 3 zdroje
- [ ] `PersonalRecentsStore` perzistuje do `AppGroupStore` JSON, cap 500 LRU, filter rules (LEN3+, max 25, no digit-only, no alphanum mix)
- [ ] `SuggestionEligibility` evaluator respektuje E1 deny-list + L2 learning whitelist + email exception
- [ ] `SlackEmojiSuggester` zabalen do `SlackSuggestionProvider`, koexistuje s WordCompletion v coordinator (Slack vždy priority)
- [ ] `SlackSuggestionBarView` refaktorován na generic `SuggestionBarView`; podporuje `.plain` (text + dividers) a `.pill` (emoji + background) render styles per chip (V2)
- [ ] `KeyboardView` integrace: bar je samostatný row nad case number row (A2), žádný mutex; always-shown když `suggestionsEnabled` + page == letters + eligibility allows (C1); empty slots hidden (F2)
- [ ] `InputDispatcher` zná `.suggestionAccept` synthesized key action: delete prefix, insert replacement + space, shift state mirror (SH3)
- [ ] Per word-boundary learning trigger v `InputDispatcher` (T1), respektuje `currentEligibility.learningContext`
- [ ] Email-field whole-field learning trigger v `KeyboardViewController` (`viewWillDisappear` + `textWillChange`), sanity check obsahuje `@` a ≤ 100 chars
- [ ] `UITextChecker` + `requestSupplementaryLexicon` eager init v `viewDidLoad` (LX2)
- [ ] `AppGroupStore.suggestionsEnabled` + `wordCompletionRecentsJSON` properties + `AppGroupStoreKey` cases + `SettingsChangeNotifier.suggestionsEnabled` Darwin notification
- [ ] Settings sekce „Suggestions" s master toggle (DEF-ON), learned count, clear button s confirmation alert (CL1), self-documenting footer copy
- [ ] Privacy policy HTML obsahuje sekci „Word suggestions" + explicit deny list
- [ ] Onboarding feature tour obsahuje položku „Private word suggestions" (FT1), pozice 2. (po diacritics)
- [ ] Lokalizace: `Settings.Suggestions.*` + `Onboarding.Tour.Suggestions.*` strings
- [ ] Tokenization rules: apostrophe in, hyphen out, Unicode letters/digits/marks in, mid-word cursor → bar collapse
- [ ] Language passed do `UITextChecker.completions(...)` z `textInputMode.primaryLanguage`, fallback `"en"` (LG2)
- [ ] Smart capitalization (CAP3) — chip text reflektuje shift state + sentence-start; tap inserts WYSIWYG
- [ ] No animation on chip swap (AN1); chip swap je direct state mutation
- [ ] Snapshot tests: 3 plain chips, 1 plain chip, empty bar, 3 pill chips, dark + light, SE width
- [ ] Unit tests: tokenizer, recents store, completion provider, coordinator priority, eligibility matrix
- [ ] Manual matrix test (#14) all-green
- [ ] README.md dual update (v1.2 sekce + Mimo scope clarification)
- [ ] Codex review mid-task (po core logic, před UI refactor) zelený nebo addressed

## Rizika

- **Cold start lag (50–100 ms first completion).** `UITextChecker.completions(...)` první volání může způsobit hitch. Mitigace: eager init v `viewDidLoad` (LX2). Fallback pokud i tak viditelné: dispatch completions na background queue + show stale chips until ready (future iteration).
- **Personal recents noise.** Mistyped words, slang, jednou-použité custom terms se ukládají; cap 500 LRU postupně vyčistí, ale do té doby může bar nabízet šum. Mitigace: clear-button v Settings, explicit footer copy „we learn from your typing".
- **Memory budget keyboard extension (~48 MB jetsam).** Aktuální overhead < 2 MB ale postupný růst (SwiftUI hosting, Slack table, recents pool, suggestion infra) se kumuluje. Mitigace: žádný explicit refactor v tomto tasku, ale poznamenat sledování `os_proc_available_memory()` v debug build do `KeyboardViewController.viewDidLoad`.
- **`requestSupplementaryLexicon` async race.** Bar se vykreslí dřív než lexicon dorazí. Mitigace: `WordCompletionProvider` má lexicon jako optional, gracefully skipuje když nil. Po completion handler kicku se `rebuild()` zavolá a chips se doplní.
- **Slack bar regression z refactoru.** Existing Slack bar je „done a otestovaný"; generic refactor riskuje regrese (visual diffs, tap targets). Mitigace: existing snapshot baselines pro Slack bar zachovat as-is (visual parity je hard test), explicit Slack-mode snapshot v novém test suite.
- **Email whole-field learning edge cases.** User v `.emailAddress` fieldu napíše multiline / comma-separated / paste → uloží se jako jeden token. Imperfect ale acceptable — sanity guards (max 100 chars, obsahuje `@`) chrání před nejhorším.
- **App Store review na on-device learning.** Reviewer může požadovat explicit disclosure o ML / learning. Mitigace: privacy policy HTML to explicit popisuje + Settings footer to popisuje + onboarding feature tour to popisuje. Triple disclosure = solid posture.
- **Privacy policy claim drift.** Pokud someone v budoucnu přidá analytics nebo telemetry, „all learning stays on this iPhone" claim se může stát unfaithful. Mitigace: poznámka v `marketing/privacy-policy.html` že každá změna v collection vyžaduje doc update; non-technical safeguard.
- **`InputDispatcher` complexity creep.** Suggestion accept path + per word-boundary learning trigger + eligibility checks se kumulují v dispatcher. Mitigace: učení vyextrahovat do `LearningHook` struct který dispatcher invokuje, ne inline kód.
- **Future `NextWordPredictionProvider` může chtít prediction i na prázdný prefix.** Aktuální `WordCompletionProvider` returns empty pro prázdný prefix. Pokud se přidá další provider, coordinator nemusí být ready pro prázdný prefix case. Mitigace: `SuggestionContext` model je extensible, ale `WordCompletionProvider` na prázdný prefix záměrně vrací empty — future provider má vlastní gate.

## Reference

- Existing suggestion bar: [`KeyboardCore/Sources/Logic/SlackEmojiSuggester.swift`](../KeyboardCore/Sources/Logic/SlackEmojiSuggester.swift), [`KeyboardUI/Sources/Views/SlackSuggestionBarView.swift`](../KeyboardUI/Sources/Views/SlackSuggestionBarView.swift), [`KeyboardUI/Sources/Views/KeyboardView.swift`](../KeyboardUI/Sources/Views/KeyboardView.swift)
- Existing dispatcher: [`KeyboardCore/Sources/Logic/InputDispatcher.swift`](../KeyboardCore/Sources/Logic/InputDispatcher.swift)
- Existing shift state: [`KeyboardCore/Sources/Logic/ShiftStateMachine.swift`](../KeyboardCore/Sources/Logic/ShiftStateMachine.swift), [`KeyboardCore/Sources/Logic/AutoCapitalizer.swift`](../KeyboardCore/Sources/Logic/AutoCapitalizer.swift)
- Existing recents/favorites persistence pattern: [`KeyboardExtension/Sources/KeyboardViewController.swift`](../KeyboardExtension/Sources/KeyboardViewController.swift) `recordRecentEmojiIfNeeded`, `toggleFavorite`
- `AppGroupStore`: [`KeyboCore/Sources/Shared/AppGroupStore.swift`](../KeyboCore/Sources/Shared/AppGroupStore.swift), [`AppGroupStoreKey.swift`](../KeyboCore/Sources/Shared/AppGroupStoreKey.swift)
- Onboarding feature tour: task [38](38-onboarding-feature-tour.md), [`Features/Onboarding/Sources/FeatureHighlight.swift`](../Features/Onboarding/Sources/FeatureHighlight.swift)
- Privacy doc: [`marketing/privacy-policy.html`](../marketing/privacy-policy.html), task [13](13-about-and-privacy.md)
- Settings UI: [`Features/Settings/Sources/SettingsView.swift`](../Features/Settings/Sources/SettingsView.swift), task [12](12-host-app-settings.md)
- Apple API: [`UITextChecker`](https://developer.apple.com/documentation/uikit/uitextchecker), [`UILexicon`](https://developer.apple.com/documentation/uikit/uilexicon), [`UIInputViewController.requestSupplementaryLexicon`](https://developer.apple.com/documentation/uikit/uiinputviewcontroller/1614506-requestsupplementarylexicon), [`UITextInputMode.primaryLanguage`](https://developer.apple.com/documentation/uikit/uitextinputmode/1614517-primarylanguage)
- iOS keyboard extension memory limit reference: žádný oficiální dokument; empirically ~48 MB jetsam threshold pozorovaný v praxi (2024–2026 iOS versions).

## Codex review

**Ano — codex review je explicitně required.**

Důvody:
- **Privacy-sensitive persistence.** Recents pool obsahuje user-typed words + email addresses; review chytí mismatch mezi privacy doc claim a actual code path (např. learning v deny-list fieldu).
- **Complex ranking logic.** Weighted merge math, dedupe edge cases, tie-break stability. Easy off-by-one bugs.
- **Tokenization edge cases.** Apostrophe / hyphen / Unicode / mid-word cursor mají subtle traps. Review katalyzuje nedotčené case.
- **Bar UI refactor.** Existing Slack bar je production code; review verifuje visual + tap target parity post-refactor.
- **`KeyboardViewController` rozšíření.** Dispatcher hook, eligibility re-eval, language detection, eager init — multiple lifecycle methods touched. Review chytí lifecycle order bugs.

**Timing:** mid-task — po dokončení scope #1–#6 (core providers, recents store, dispatcher hook, state extension), před UI refactor (#5) a Settings integrace (#9). Důvod: codex chytí logic bugs než zarefactoruješ celé bar UI okolo nich. Druhý lighter pass před closing commit.
