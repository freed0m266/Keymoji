# 43 — Task dashboard HTML generator

**Status:** Done — 2026-05-29

**Priorita:** Tech debt · **Úsilí:** S · **Dopad:** Medium (osobní produktivita: s 42+ tasky ztrácím přehled, co je v jakém stavu)

## Souhrn

Skript `scripts/generate_dashboard.py`, který vyparsuje task soubory v `tasks/[0-9]*.md` a vyplivne statický `tasks/dashboard.html` — minimalistický dark-mode Kanban přehled. Tři sloupce (Draft / Todo / Done), karty s metadaty, sticky header s progress bary per verze, search box + filtr chips podle priority. Po vygenerování se HTML otevře v prohlížeči.

Cíl je rychle vidět *kde jsem* — kolik je v jaké verzi hotovo, co je v Todo, co jsou jen rough drafty. Ne nahrazovat README (ten zůstává kanonický a držený ručně), ale doplnit pohled, který README nedává: aktuální status snapshot v jednom obrázku.

## Co přesně chceme (a co ne)

**Chceme:**

- Jedno spuštění: `python3 scripts/generate_dashboard.py` → přepíše `tasks/dashboard.html` a `open`-ne ho.
- Žádné non-stdlib deps. Jen `re`, `pathlib`, `html`, `subprocess`, `argparse`, `datetime`, `collections` ze stdlib.
- Single self-contained HTML file — inline `<style>` a `<script>`. Žádné external CSS/JS/font CDN (offline-friendly, žádný flicker při open).
- Outputs committed do gitu. Dashboard se obnovuje *ručně* po větší změně, ne při každém commitu.

**Nechceme:**

- Žádný markdown parser (parsujeme jen řádky metadat + první paragraf nadpisu regexem).
- Žádné external dependencies, žádné `pip install`.
- Žádný backend, žádný server, žádné fetchování za běhu.
- Žádný auto-update na file watcher / git hook (záměrně manual — víc kontroly).
- Žádný clickthrough z karty na `.md` (decidedly out — search v rámci dashboardu stačí, hlubší pohled se dělá v editoru).

## Doporučený přístup

### 1. Parsing (`scripts/generate_dashboard.py`)

Pro každý `tasks/[0-9]*.md` soubor (řazeno podle čísla) extrahovat:

- **Číslo** — z filename (`(\d+)-` prefix).
- **Title** — z `# NN — Title` (cokoliv po em-dash nebo dvojitém dash).
- **Status** — řádek `**Status:** ...`. Tři normalizované hodnoty:
  - `Draft` (regex `^\s*Draft\b`)
  - `Done` + completion date (regex `^\s*Done\s*[—–-]\s*(\d{4}-\d{2}-\d{2})`)
  - `Todo` (regex `^\s*Todo\b`)
  - Cokoliv jiného → hard fail s file path + raw řádkem (lepší signál než silent skip).
- **Priorita** — z `**Priorita:** X · **Úsilí:** Y · **Dopad:** Z` (separator je `·` = U+00B7). Priorita normalizovaná na bucket:
  - Pokud začíná `v\d+\.\d+` → bucket je ten version string (`v1.0`, `v1.1`, `v1.2`, …) — *nehardcodovat* seznam, parsovat z dat.
  - Jinak whole label trimmed (`Tech debt`, `Pre-App-Store`).
  - Plný originální string (např. `v1.1 polish`, `Tech debt`) si nech pro display v badge.
- **Úsilí** — single token (`S` / `M` / `L` / případně `S-M`, `M-L` — display as-is).
- **Dopad** — první slovo před závorkou nebo dlouhou poznámkou, pro klasifikaci do barvy:
  - `Blokující` → red-ish
  - `High` → orange
  - `Medium` → yellow
  - `Low` → muted gray
  - `None` → muted gray
  - Cokoliv jiného → muted gray + display raw label.
- **Summary** — najít první `## Cíl` NEBO `## Souhrn` (cokoliv přijde dřív), vzít první ne-prázdný paragraf (do první prázdné řádky), strip markdown linky (`[text](href)` → `text`), inline kód (`` ` `` zahodit), bold (`**x**` → `x`). Truncate na 180 znaků s `…` (zachovat slovní hranici).
- Pokud žádná z těch sekcí neexistuje → summary je prázdný string (warning na stderr, ne hard fail).

### 2. Sorting a grouping

Tasky rozdělit do tří sloupců podle statusu. V sloupci řadit:

- **Draft:** podle čísla tasku rostoucně.
- **Todo:** podle priority bucket (přírodní řazení: `v1.0` < `v1.1` < `v1.2` < … < `Tech debt` < `Pre-App-Store` < ostatní), uvnitř bucketu podle čísla tasku rostoucně.
- **Done:** podle completion date sestupně (čerstvě dokončené nahoře), tie-break podle čísla tasku sestupně.

Pro progress bary v hlavičce: per bucket spočítat `done / total` a vyrenderovat jeden progress bar per bucket. Bucket pořadí stejné jako Todo sort (v1.0 první).

### 3. HTML render

Jeden `<!DOCTYPE html>` soubor. Struktura:

```
<header sticky>
  <h1>Keymoji tasks</h1>
  <div class="stats">
    <span>NN total · NN done · NN todo · NN draft</span>
  </div>
  <div class="progress-grid">
    {progress bar per bucket}
  </div>
  <div class="controls">
    <input type="search" placeholder="Search title or summary…">
    <div class="filter-chips">
      <button data-filter="all" class="active">All</button>
      {chip per bucket}
    </div>
  </div>
</header>
<main class="board">
  <section class="column" data-status="draft">
    <h2>Draft <span class="count">N</span></h2>
    {cards}
  </section>
  <section class="column" data-status="todo">…</section>
  <section class="column" data-status="done">…</section>
</main>
```

Karta:

```
<article class="card" data-priority="v1.0" data-impact="high" data-search="lowercased title + summary">
  <header>
    <span class="num">#NN</span>
    <h3>Title</h3>
  </header>
  <div class="badges">
    <span class="badge priority">v1.0</span>
    <span class="badge effort">M</span>
    <span class="badge impact impact-high">High</span>
  </div>
  <p class="summary">First paragraph…</p>
  <footer>Done 2026-05-24</footer> <!-- jen pro Done -->
</article>
```

### 4. Styling (inline `<style>`)

- Background: `#0a0a0a` (near-black, ne pure black — měkčí na očích).
- Text base: `#e5e5e5`, secondary `#888`, dimmed `#555`.
- Font: system stack `-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`. Mono pro čísla a datumy: `ui-monospace, "SF Mono", Menlo, monospace`.
- Sloupce: tři fixní široké kolony (`grid-template-columns: repeat(3, 1fr)`, `gap: 16px`). Na narrow viewportech (`< 900px`) jeden sloupec pod druhým (acceptable degradation; primárně desktop).
- Sloupec status-color tint: jemný `border-top: 2px solid {color}` (Draft: `#555`, Todo: `#5b9bd5`, Done: `#6abf69`). Žádný background tint sloupce — drží to klid.
- Karta: `background: #141414; border: 1px solid #222; border-radius: 8px; padding: 14px;`. Hover: `border-color: #333`.
- Badge: pill shape (`border-radius: 999px; padding: 2px 8px; font-size: 11px;`), outline-style pro priority a effort (`border: 1px solid #333; color: #aaa`), vyplněný pro impact:
  - `impact-blocking`: `background: #5a1f1f; color: #ffb4b4;`
  - `impact-high`: `background: #5a3a1f; color: #ffd4a8;`
  - `impact-medium`: `background: #4a4a1f; color: #f0e0a0;`
  - `impact-low`, `impact-none`, fallback: `background: #2a2a2a; color: #888;`
- Progress bar: tenký 6px track, fill v barvě bucketu (v1.0/v1.1 use jeden accent jako `#6abf69`, ostatní `#888`). Vedle baru text `v1.0 — 15/15 (100%)`.
- Search input: full-width na header row, monochromatic (`background: #141414; border: 1px solid #222`).
- Filter chips: stejný pill style jako badges, active stav má `background: #333; color: #fff`.

### 5. Interaktivita (inline `<script>`, vanilla JS)

- Search input → onfilter: pro každý `.card` koukni na `data-search` atribut (lowercased title + summary), nastav `hidden` podle substring match. Pak update sloupcový `.count` na visible cards.
- Filter chips → toggle aktivní chipu, filtruj karty podle `data-priority`. „All" zruší filter. Search a chip se aplikují AND.
- Žádný framework. Jednoduché `addEventListener`, `querySelectorAll`.

### 6. CLI

```python
parser.add_argument('--no-open', action='store_true', help='Skip opening in browser')
parser.add_argument('--out', default='tasks/dashboard.html')
```

Po zápisu: print `✓ Wrote {path} ({n} tasks: {n_draft} draft, {n_todo} todo, {n_done} done)`. Pokud `--no-open` není set, `subprocess.run(['open', str(path)], check=False)`.

## Scope

1. `scripts/generate_dashboard.py` — parser + renderer + CLI, single file Python script.
2. První vygenerování → `tasks/dashboard.html` committed.
3. Aktualizovat `tasks/README.md` o jeden řádek úplně nahoře (pod nadpisem): `> Aktuální status snapshot: [dashboard.html](dashboard.html) (regenerate s `python3 scripts/generate_dashboard.py`).`

## Mimo scope

- **README struktura grouping** (v1.0 Core / v1.0 Host app / v1.0 Visual polish dílčí sekce). Skript je neignoruje vědomě, jen je nepoužívá — bucket je flat (v1.0 / v1.1 / Tech debt / Pre-App-Store / …).
- **„Mimo scope úplně"** seznam z README — to nejsou tasky, do dashboardu nepatří.
- **Click-through z karty na zdrojový `.md`.** Záměrně out (search v dashboardu stačí; hlubší pohled je v editoru).
- **In Progress status.** V datech neexistuje, nezavádíme ho preventivně.
- **Auto-regen** (file watcher, git hook, CI). Záměrně manuální.
- **GitHub Pages hosting / sdílení.** Lokální tool pro mě.
- **Mobile-first responsive.** Pod 900px jeden sloupec pod druhým (acceptable degradation), nic dalšího se neoptimalizuje.
- **Webfonty, external CSS/JS.** Vše inline.

## Hotovo když

- [ ] `python3 scripts/generate_dashboard.py` z čistého stavu vygeneruje `tasks/dashboard.html` bez chyb, parsuje všech 42+ tasků.
- [ ] HTML se automaticky otevře v defaultním prohlížeči (lze potlačit `--no-open`).
- [ ] Tři sloupce (Draft / Todo / Done) ukazují správné počty, součet = total počet task souborů.
- [ ] Progress bary per bucket souhlasí s ručním napočítáním (např. v1.0 done count).
- [ ] Search filtruje karty real-time (psaní zužuje výsledky, mazání rozšiřuje).
- [ ] Filtr chips podle priority funguje, kombinuje se se searchem (AND).
- [ ] Done karty mají completion date, ostatní ne.
- [ ] Badge impact barva odpovídá pravidlu (Blokující červená, High oranžová, Medium žlutá, Low/None šedá).
- [ ] Otevřeno v dark prohlížeči — žádný flash bílého pozadí při loadu (background v `<html>` i `<body>` nastaven okamžitě).
- [ ] Malformed status řádek v některém tasku → skript hard-failne s file path a problematickým řádkem (smoke test: dočasně zlomit jeden file, ověřit, vrátit).
- [ ] `tasks/README.md` má nahoře odkaz na dashboard.
- [ ] Skript je idempotentní (druhý běh produkuje byte-identický output, pokud se data nezměnila → diff-friendly v gitu).

## Reference

- [`tasks/README.md`](README.md) — kanonický seznam a grouping, source pro pochopení priorit.
- [`scripts/generate_emoji_search_data.sh`](../scripts/generate_emoji_search_data.sh) — precedent generátor v `scripts/` (shell, ale stejný „regenerate on demand, commit output" pattern).
- [`tasks/42-inter-key-gap-hit-areas.md`](42-inter-key-gap-hit-areas.md) — vzor task format se vším (Souhrn / Co přesně chceme / Doporučený přístup / Scope / Mimo scope / Hotovo když).
- [`tasks/02-layout-model.md`](02-layout-model.md), [`tasks/40-word-completion-suggestions.md`](40-word-completion-suggestions.md) — ukázky variability metadat (Cíl vs Souhrn, v1.0 vs v1.2 priorita, Done s datumem vs Draft).
