# Folio — Implementation Roadmap

> **For future Claude sessions:** this file is the canonical guide for the Folio project. Read it before doing anything else. Update the **Status** table as milestones land. Don't restart planning from scratch — extend or amend this doc.

---

## How to use this file

1. **Read top-to-bottom on first session of the project** (or after a long pause).
2. The **Status** table below is the live state — update it as milestones complete.
3. The **Open questions** section is the only place where decisions are pending — resolve them inline (cross out, replace with the chosen answer + date).
4. The **Locked decisions** table is append-only-ish: if a decision changes, leave the old row struck-through with a brief note so future sessions see the history.
5. The original visual spec lives in the design bundle (paths in **Critical references**). Treat it as read-only — it doesn't get re-exported.

---

## Status

| Milestone | State | Notes |
|---|---|---|
| M0 — Project scaffold (Tuist) | ✓ done (2026-05-20) | Tuist 4.195.2 · Xcode 26.4 · Swift 6.3 · `xcodebuild build` and `test` both green |
| M1 — Design system | ✓ done (2026-05-20) | `FolioTheme` light+dark · `\.theme` env · 7 primitives (Card / Metric / SectionHeader / PeriodPills / AccountBadge / Dot / AllocBar) · `FolioFormat` (USD/pct/num) · `DesignSystemPreview` wired into ContentView |
| M2 — Shell + navigation | ✓ done (2026-05-20) | Custom `NavigationSplitView` sidebar (3 groups, v2 rows dimmed) · `AppRouter` (`@Observable`) · ⌘1–⌘4 via `Commands` block · native toolbar with `.navigationSubtitle` + ⌘K search stub + "+ Add holding" sheet stub · `PlaceholderScreen` in detail slot |
| M3 — Domain model + persistence | ✓ done (2026-05-20) | SwiftData schema (6 entities; `Transaction` → `PortfolioTransaction` to avoid SwiftUI collision) · `Money` value type (Decimal+ISO, decomposed in storage) · `HoldingsReducer` `@MainActor` with closure-injected price+FX · weighted-avg cost basis (sells reduce qty and cost proportionally) · seed loader idempotent on empty DB · 19 tests green · sidebar footer now `@Query`-bound |
| M4 — Quote + FX service | ☐ not started | |
| M5 — Stocks & ETFs screen | ☐ not started | |
| M6 — Crypto screen | ☐ not started | |
| M7 — Transactions screen | ☐ not started | |
| M8 — Overview MVP (chart-less) | ☐ not started | Chart slot reserved pending open question |
| M9 — Add Transaction flow | ☐ not started | |
| M10 — Settings + polish | ☐ not started | |
| M11 — Test + verify | ☐ not started | |

Legend: ☐ not started · ◐ in progress · ✓ done · ✕ skipped/changed

---

## Toolchain (verified 2026-05-20)

- macOS 26 (Darwin 25.x), Apple Silicon
- Xcode 26.4 — Swift 6.3 (Apple swift-driver 1.148.6)
- Tuist 4.195.2 (installed via Homebrew)
- Homebrew 5.1.8

**Fresh-machine setup:** `brew install tuist` → in the repo: `tuist generate && open Folio.xcworkspace`. Then ⌘R to run.

**Headless rebuild from CLI:** `tuist generate && xcodebuild -workspace Folio.xcworkspace -scheme Folio -destination 'platform=macOS' build` (add `test` for the test target).

---

## Context

**Folio** is a macOS desktop portfolio tracker the user designed in claude.ai/design and exported as a handoff bundle. The bundle contains a React/HTML prototype with 8 polished screens, theme tokens, and mock data. We treat it as the **visual specification** — the real app is a native **SwiftUI app for macOS 14 Sonoma+**.

The repo `global_wallet` was empty when the project began (just a README). Product name is **Folio**; repo name stays as-is. Goal: a local-first, single-user desktop app for tracking stocks/ETFs and crypto across multiple brokerages and wallets, with multi-currency support.

---

## Locked decisions

| Decision | Choice |
|---|---|
| Runtime | Native macOS, SwiftUI, deployment target macOS 14 Sonoma+ |
| Persistence | SwiftData (local SQLite-backed, no cloud) |
| Project layout | **Tuist** (`Project.swift` manifest → generated `.xcodeproj`, gitignored) |
| Currency | Multi-currency, user-picked **base currency**, FX rates fetched daily |
| Data model | **Transactions = source of truth**; holdings are a computed projection |
| Quote provider | Swappable `QuoteProvider` protocol; default = **Yahoo (unofficial)** for stocks/FX + **CoinGecko** for crypto |
| Auth / backend | None — single user, single machine |
| Distribution | Personal use, unsigned local builds (no Developer ID until shared) |
| MVP scope | 4 screens: Overview, Stocks & ETFs, Crypto, Transactions |
| v2 backlog | Dividends, Fees, Accounts CRUD, Import CSV, FIFO/LIFO costing |
| Charting | Swift Charts (built-in, macOS 13+) |
| Cost basis (MVP) | Weighted average cost (FIFO/LIFO deferred to v2) |
| Money type | `Decimal`-backed value type with ISO currency tag; decomposed into sibling `amount: Decimal` + `currency: String` columns in SwiftData (computed `…Money` accessor) |
| Ledger model name | `PortfolioTransaction` (the `@Model` class) to avoid colliding with `SwiftUI.Transaction`; UI label stays "Transactions" |

---

## Open questions (do not block MVP)

- **Overview chart strategy** — choose between:
  - (a) real historical portfolio value computed from holdings × historical closes,
  - (b) snapshot approximation (assume current holdings always held),
  - (c) defer chart to v2.
  Plan ships Overview MVP **without** the chart; M8 leaves a layout slot. Decide before M8 implementation.
- **Quote refresh cadence** — proposed: on-launch + manual `⌘R` + 15-min foreground timer; revisit at M4.

---

## Architecture at a glance

Legend: **[✓ Mn]** = exists on disk · **[Mn]** = planned for that milestone.

```
global_wallet/
├── Tuist.swift                                — Tuist config                        [✓ M0]
├── Project.swift                              — project manifest (targets + settings) [✓ M0]
├── .gitignore                                 — ignores .xcodeproj, Derived/, etc.  [✓ M0]
├── ROADMAP.md                                 — this file
├── Folio.xcworkspace / Folio.xcodeproj        — generated, gitignored
└── Folio/
    ├── Sources/
    │   ├── App/                                                                     [✓ M0, M2]
    │   │   ├── FolioApp.swift                 — @main, WindowGroup, 960×600 min,
    │   │   │                                    AppRouter + ⌘1–⌘4 Commands
    │   │   └── ContentView.swift              — thin DesignSystemPreview wrapper
    │   │                                        kept only for SwiftUI previews
    │   ├── DesignSystem/                                                            [✓ M1]
    │   │   ├── Theme.swift                    — FolioTheme light + dark; \.theme env
    │   │   ├── Color+Hex.swift                — Color(hex: 0xRRGGBB, opacity:)
    │   │   ├── Formatters.swift               — FolioFormat (usd/pct/num)
    │   │   ├── DesignSystemPreview.swift      — debug QA screen
    │   │   └── Components/                    — Card, Metric, SectionHeader,
    │   │                                        PeriodPills, AccountBadge, Dot, AllocBar
    │   ├── Models/                            — SwiftData @Model entities          [✓ M3]
    │   │                                        (Account, Asset,
    │   │                                         PortfolioTransaction,
    │   │                                         PriceQuote, FXRate, AppSettings)
    │   │                                        + Enums.swift, SeedData.swift
    │   ├── Domain/                            — Money, Holding, HoldingsReducer,   [✓ M3]
    │   │                                        PortfolioMetrics
    │   ├── Services/                          — QuoteProvider protocol + impls +   [M4]
    │   │                                        QuoteRefreshCoordinator
    │   └── Features/
    │       ├── Shell/                         — NavigationSplitView + sidebar      [✓ M2]
    │       ├── Overview/                                                            [M8]
    │       ├── Stocks/                                                              [M5]
    │       ├── Crypto/                                                              [M6]
    │       ├── Transactions/                                                        [M7]
    │       ├── Settings/                      — base currency, theme override      [M10]
    │       └── AddTransaction/                — + Add holding sheet                 [M9]
    └── Tests/                                                                       [✓ M0]
        └── FolioTests.swift                   — placeholder; per-milestone tests
                                                  added as we go (M11)
```

---

## Milestones

### M0 — Project scaffold
- Install Tuist (`brew install tuist`).
- Author `Tuist/Project.swift` with one app target (macOS 14+) + one test target.
- `tuist generate` → open in Xcode → empty window builds and runs.
- `.gitignore` excludes `.xcodeproj`, `Derived/`, `.build/`.
- App display name = **Folio**; bundle id = `co.bff.folio` (or your preferred reverse-DNS).

**Result (2026-05-20):** Shipped `Tuist.swift`, `Project.swift`, `.gitignore`, `Folio/Sources/App/{FolioApp,ContentView}.swift`, `Folio/Tests/FolioTests.swift`. App target signs ad-hoc (`CODE_SIGN_IDENTITY = "-"`, hardened runtime disabled for local dev). `tuist generate` produces a clean workspace; `xcodebuild build` and `xcodebuild test` both green.

### M1 — Design system
- Port the prototype's `F.*` tokens (`project/theme.jsx`, `project/primitives.jsx`) to `Theme.swift` with full **light + dark** palettes; expose via `@Environment(\.theme)`.
- Base components: `Card`, `Metric`, `AllocBar`, `AccountBadge`, `PeriodPills`, `Dot`, `SectionHeader`.
- Monospace tabular-number formatters (`Money.formatted(...)`, `Percent.formatted(...)`).
- A debug-only `DesignSystemPreview` screen for visual QA.

**Result (2026-05-20):** All 7 primitives shipped under `Folio/Sources/DesignSystem/Components/`. `FolioTheme` provides light + dark palettes; `\.theme` resolves from `\.colorScheme` via `.folioTheme()` modifier (M10 will swap that provider for an AppSettings-driven one that supports a user override). `FolioFormat` (USD/pct/num) lives in `Formatters.swift` — these are USD-only placeholders that get superseded by `Money.formatted(...)` in M3. `ContentView` currently hosts `DesignSystemPreview`; **M2 replaces that with `MacShell`**. Introduced a shared `FolioTone { neutral, positive, negative }` enum used by `Metric` sub/badge tones — reuse for table cells in M5–M7.

### M2 — Shell + navigation
- `NavigationSplitView` with sidebar matching `project/shell.jsx`:
  - Top group: Overview / Stocks & ETFs / Crypto / Transactions
  - "Settings" group (Accounts + Import slots reserved for v2)
- Titlebar: page title + subtitle, ⌘K search field (visible but non-functional in MVP), `+ Add holding` toolbar button → opens M9 sheet.
- ⌘1–⌘4 keyboard shortcuts to switch tabs.
- Use **native** macOS traffic lights and titlebar — do not custom-draw the chrome from the prototype.
- Sidebar footer shows portfolio total + account count (live-bound to M3).

**Result (2026-05-20):** Shipped 9 files under `Folio/Sources/Features/Shell/`: `Destination.swift` (enum + `SidebarGroup` metadata), `AppRouter.swift` (`@Observable`, holds `selection` + `showAddSheet`), `MacShell.swift` (`NavigationSplitView` with `$columnVisibility`, native toolbar via `.toolbar`, `.navigationTitle`, `.navigationSubtitle`, sheet mounted on the detail container), `SidebarView.swift` (fully custom non-`List` sidebar with brand-mark row at the top — traffic lights overlay onto `sidebarBg`), `SidebarItem.swift` (Button for MVP rows, plain HStack with `.opacity(0.45)` + `.allowsHitTesting(false)` for v2), `SidebarGroupHeader.swift`, `SidebarFooter.swift` (static "Folio · 0 accounts · $0.00" — wired live in M3), `ToolbarSearchStub.swift` (non-functional `.allowsHitTesting(false)` HStack with magnifying-glass + "⌘K" hint — real search in M10), `AddTransactionStubSheet.swift` (480×220 placeholder sheet — replaced by real form in M9), `PlaceholderScreen.swift` (centered empty state per destination). `FolioApp.swift` instantiates `AppRouter` as `@State`, injects via `.environment(router)`, hoists `.folioTheme()` to `WindowGroup` (single-line swap in M10), and registers ⌘1–⌘4 via `CommandGroup(after: .sidebar)` mutating `router.selection` directly (no NotificationCenter). `ContentView.swift` is now a thin wrapper around `DesignSystemPreview` retained only so the existing SwiftUI previews compile. `tuist generate && xcodebuild build && xcodebuild test` all green. **Note:** SourceKit reported ~25 bogus "Cannot find type X in scope" errors during multi-file authoring; all cleared on the next `tuist generate` (per the workflow note about SourceKit lying after new files).

### M3 — Domain model + persistence
- SwiftData entities: `Account`, `Asset`, `Transaction`, `PriceQuote`, `FXRate`, `AppSettings`.
- `Money` value type — **never `Double` for money**; arithmetic via `Decimal`.
- Seed a dev DB on first launch from `project/data.jsx` (port the mock dataset) so subsequent UI work has realistic fixtures.
- `HoldingsReducer`: given `[Transaction]` + FX/quote context → `[Holding]` with qty, costBasis in base currency (FX-converted at txn date), avgCost.

**Result (2026-05-20):** Shipped 11 new files under `Folio/Sources/Models/` and `Folio/Sources/Domain/` + `Folio/Sources/App/ModelContainer+Folio.swift`. The `@Model` class is `PortfolioTransaction` (not `Transaction`) to avoid colliding with `SwiftUI.Transaction` — UI label stays "Transactions". Storage: `Decimal` and Codable enums persist natively on macOS 14 SwiftData; `Money` decomposes into sibling `amount: Decimal` + `currency: String` fields on each model (computed `…Money` accessor). Relationships: `Account.transactions` cascade-deletes; `Asset.transactions` is `.nullify` (deleting an asset preserves the audit trail); `Asset.quotes` cascade-deletes (cache); `PortfolioTransaction.transferDestination` has no declared inverse (avoids ambiguity with `account`). `@Attribute(.unique)` on `Account.name`, `Asset.symbol`, `FXRate.key`. `AppSettings` is singleton-by-convention, ensured by the `ModelContainer.folio()` factory. `HoldingsReducer` is `@MainActor`, takes `priceFor: (Asset) -> Decimal?` and `fxAt: (String, String, Date) -> Decimal?` closures — M4 will swap both. Weighted-avg cost basis: sells reduce qty **and** cost proportionally so per-share avg stays stable across sales (initial implementation had a bug — caught by `testTslaSellReducesQtyButPreservesAvgCost`, fixed before commit). Seeder loads 9 accounts + 16 assets + 16 quotes + 34 transactions (10 stock buys + 12 crypto-wallet buys + 12 mock txns) on empty DB; idempotent on re-launch. `FolioApp` builds `try ModelContainer.folio()` in `init` and attaches via `.modelContainer(container)`. `SidebarFooter` now reads `@Query` for `Account.count` and `AppSettings.baseCurrency`; total is still `Money.zero(baseCurrency).formatted()` placeholder until M4 wires `PriceQuote` → reducer. 19 tests across `MoneyTests`/`HoldingsReducerTests`/`SeedTests` all pass. SwiftData store at `~/Library/Application Support/default.store` (unsandboxed) — `sqlite3` row-count spot-check confirms the expected 9/16/34/16/0/1.

### M4 — Quote + FX service
- `QuoteProvider` protocol: `quote(symbol:)`, `historical(symbol:, range:)`, `search(query:)`.
- `MockQuoteProvider` (deterministic random walk; matches the prototype's series generator) for tests + offline dev.
- `YahooQuoteProvider` (stocks/ETFs/FX) and `CoinGeckoQuoteProvider` (crypto) — gated behind the protocol so swapping is one DI change.
- `QuoteRefreshCoordinator`: refresh on launch, manual `⌘R`, 15-min foreground timer. Writes to `PriceQuote` cache.
- Failures surface as a non-blocking banner — quotes are best-effort, never crash the app.

### M5 — Stocks & ETFs screen
Spec: `project/stocks.jsx`.
- 3 summary cards: Market Value, Unrealized P&L (with %), Dividends YTD (placeholder zero until v2 Dividends ships).
- Dense sortable table: ticker + name + account badge, qty, avg cost, current price, market value, P&L $, P&L %, allocation bar.
- Row hover, theme-aware green/red P&L, monospace numbers.
- Data flows from `HoldingsReducer` filtered to `Asset.kind in [.stock, .etf]`.

### M6 — Crypto screen
Spec: `project/crypto.jsx`.
- Same shape as Stocks, but each asset row is **expandable** to reveal per-wallet sub-rows (Binance / Ledger / MetaMask / Coinbase / Phantom) with colored dot, qty, avg cost, value.
- Wallet aggregation: group an asset's transactions by `account` where `kind in [.wallet, .exchange]`.

### M7 — Transactions screen
Spec: `project/transactions.jsx`.
- Sortable table: date, type badge, asset, qty, price, total, account badge.
- Filter pills: All / Buys / Sells / Income / Transfers.
- Search by ticker or asset name.

### M8 — Overview MVP (chart-less)
Spec: `project/overview.jsx`.
- 4 metric cards: Total Value, All-time Gain ($ + %), YTD Performance, Invested Capital — all computed from transactions × current quotes via `PortfolioMetrics`.
- Asset Allocation split bar (Stocks / Crypto / Cash) using current market values.
- Annual Performance table with BEST/WORST badges — partial-year rows allowed when quote history is incomplete.
- **Reserved chart slot** in the layout; populated once the open question is answered.

### M9 — Add Transaction flow
- `+ Add holding` toolbar action → sheet.
- Form fields: type, date, account, asset (symbol autocomplete via `QuoteProvider.search`), qty, price, total, fee, notes.
- Validates transaction currency against account currency; shows live FX preview when they differ.

### M10 — Settings + polish
- Settings sheet: base currency picker (drives all displayed values), theme override (**System / Light / Dark** — matches the prototype's Tweaks panel), default cost-basis (locked to AvgCost in MVP), reveal-data-folder action.
- Currency formatting respects user locale + base currency.
- ⌘K search wired to a holdings/asset finder.
- Empty states for each screen (no holdings yet, no transactions yet, quote provider offline).

### M11 — Test + verify
- Unit tests: `HoldingsReducer` (multi-currency, sells reduce basis correctly, edge cases), `Money` arithmetic, `PortfolioMetrics`, `MockQuoteProvider`.
- Snapshot tests for each MVP screen at light + dark, seeded with the mock fixture data.
- Manual verification checklist (see Verification section below).

---

## v2 backlog (after MVP)
- Resolve Overview chart open question; implement chosen approach.
- **Dividends** screen — spec in `project/dividends.jsx`.
- **Fees** screen — spec in `project/fees.jsx`.
- **Accounts CRUD** screen — spec in `project/settings.jsx` (grouped by Brokerage / Exchange / Wallet).
- **Import CSV** — start with a generic column-mapper UI, then add bank-specific presets (Schwab, Fidelity, Vanguard, Robinhood, Coinbase, Binance) opportunistically.
- FIFO/LIFO cost-basis options.
- Plaid/SnapTrade live broker sync (only if you want to leave local-only).
- Code signing + notarization once you want to share builds.

---

## Verification

**Per milestone:**
1. `tuist generate && xcodebuild -scheme Folio -destination 'platform=macOS' build` succeeds.
2. Open in Xcode, run, smoke-test the affected screen.
3. New tests for that milestone pass: `xcodebuild test -scheme Folio`.

**End-to-end MVP (after M11):**
- Launch with empty DB → first-run prompt picks a base currency.
- Add ~10 transactions across stocks + crypto + ≥3 accounts of mixed kinds.
- Overview totals match a hand-computation (or a quick spreadsheet).
- Stocks/Crypto tables match (qty, avg cost, P&L %, allocation %s sum to 100).
- Transactions screen filters and sorts correctly.
- Toggle theme override → instant, no flicker.
- Switch base currency → all displayed values reformat; FX rates fetched if missing.
- Kill the app, relaunch → state persists.
- Airplane mode → quote refresh fails gracefully (banner, cached prices remain).

---

## Critical references (read these before each screen milestone)

The design handoff bundle lives outside the repo at:
`/Users/arnaudhuret/.claude/projects/-Volumes-ARNAUD-SSD-projects-global-wallet/66e3c238-566d-4a4f-b09b-d4f762a34c2b/tool-results/folio_design/finance-app/`

If that path is gone (different machine, cleared cache), re-fetch with:
`WebFetch` on `https://api.anthropic.com/v1/design/h/A_-WkNGLRFKfHnsdlX17yQ?open_file=Folio.html` → gzip → tar.

Key files inside the bundle:
- `README.md` — handoff instructions
- `chats/chat1.md` — original brief + canonical design-system declaration (colors and tokens). `chat2.md` is empty.
- `project/Folio.html` — index, defines screen load order
- `project/data.jsx` — mock dataset; port to dev seed
- `project/theme.jsx` + `project/primitives.jsx` — port directly into `DesignSystem/`
- `project/shell.jsx` — sidebar/titlebar spec (M2)
- `project/overview.jsx` / `stocks.jsx` / `crypto.jsx` / `transactions.jsx` — MVP screen specs (M5–M8)
- `project/dividends.jsx` / `fees.jsx` / `settings.jsx` — v2 specs
- `project/tweaks-panel.jsx` — theme picker pattern; surfaced in macOS Settings

---

## Workflow notes for future sessions

- Check in with the user between milestones; M3 (schema), M4 (provider impls), and M8 (chart decision) are natural decision points.
- Commits per milestone, not per file, and only when the user says so.
- Live API calls (Yahoo, CoinGecko) are skipped in tests via `MockQuoteProvider`; never hit them from CI.
- When in doubt about a design detail, **read the prototype source**, not the chats — the JSX files are the precise spec.
- The user prefers planning be done thoroughly upfront via `EnterPlanMode` + `AskUserQuestion` rather than implementation-first.
- **SourceKit lies after adding new files.** Tuist resolves `Sources/**` into explicit `.pbxproj` entries at generate-time, so newly written `.swift` files are invisible to SourceKit until you run `tuist generate` again. Mid-edit diagnostics like *"Cannot find X in scope"* or *"No exact matches in call to initializer"* during a multi-file write are almost always this — confirm with a real `xcodebuild build` before chasing them. (Re-run `tuist generate` after every new file to silence them.)
- After a clean build, the app launches from `~/Library/Developer/Xcode/DerivedData/Folio-*/Build/Products/Debug/Folio.app` — handy for `open`-launching headlessly to visually verify a milestone without opening Xcode.
