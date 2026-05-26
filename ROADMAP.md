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
| M4 — Quote + FX service | ✓ done (2026-05-21) | `QuoteProvider` + `FXProvider` protocols · `MockQuoteProvider` (LCG walk + fixed FX) · `YahooQuoteProvider` (stocks/ETFs/FX, `.`→`-` symbol fix for BRK.B) · `CoinGeckoQuoteProvider` (batched `simple/price` call, MATIC→`polygon-ecosystem-token` post-rebrand) · `QuoteRefreshCoordinator` `@Observable @MainActor` dispatching by `AssetKind` · launch + ⌘R + 15-min timer · compact toolbar status pill (green/amber/red dot, click to refresh) · `SidebarFooter` now live via `HoldingsReducer` · 30 tests green (added 11) |
| M4.5 — Pre-M5 audit + Swift 6 bump | ✓ done (2026-05-21) | Full code review of M0–M4. Fixed 5 bugs: FX cache UTC-vs-local mismatch in `QuoteRefreshCoordinator.collectFXPairs`, non-stable `Holding.id` (now derived from asset/account `PersistentIdentifier`), `MetricBadge` `.neutral` fall-through to `.negative`, `HoldingsReducer` over-sell now clamps at qty 0, `PriceQuote` rows now dedupe per (asset, source) within 60s. Bumped to Swift 6.0 + `SWIFT_STRICT_CONCURRENCY=complete` — codebase was already clean, zero new diagnostics. Test coverage near-doubled: 30 → 54 (Money decimal correctness incl. 0.1+0.2=0.3, cross-currency cost basis, full `PortfolioMetrics` suite, coordinator partial-success/total-fail, Yahoo/CoinGecko URL builders extracted + tested) |
| M5 — Stocks & ETFs screen | ✓ done (2026-05-21) | `StocksScreen` (`@Query` txns + quotes + settings) · 3-card summary (Market Value · Unrealized P&L w/ % badge · Dividends YTD live-computed from `.dividend` txns) · `FilterPill` row (All accounts + per-broker, alphabetized) · click-to-sort table headers w/ chevron indicator + `Sort by` menu fallback · custom-laid-out row HStack w/ `TickerLogo` letter-mark · row hover via `theme.rowHover` · footer totals (count + MV + P&L $ + P&L % + 100.0%) · USD-only `fxAt` until M10 base-currency picker · 6 new tests (`StocksRowsBuilderTests`) · 60 tests green |
| M6 — Crypto screen | ✓ done (2026-05-21) | `CryptoScreen` mirrors M5 shape but rows are expandable per-wallet · 3-card summary (Market Value · Unrealized P&L w/ % badge · Staking YTD live-computed from `.stake` txns on crypto kinds in current year) · wallet filter pills with leading colored `Dot` (account hex) + Expand all / Collapse all (disabled when a wallet is selected) + sort menu · click-to-sort headers (chevron column un-sortable) · `CryptoLogo` (round, palette BTC/ETH/SOL/LINK/MATIC/USDC, `$` glyph for USDC) lives under `DesignSystem/Components/` · aggregate row clickable to toggle expansion via `expanded: Set<String>` keyed by ticker (defaults open BTC + ETH per JSX) · sub-rows show indented `Dot(account.colorHex)` + wallet name + "X% of holding" + qty/cost/—/MV/PnL$/PnL%/alloc% (price intentionally `—` since asset-level) · wallet filter (selected) pre-filters txns to that account (M5 pattern) and suppresses sub-rows + chevron, shows `AccountBadge` on the aggregate · allocation denominator = crypto subtotal in both rows and sub-rows so footer reads `100.0%` · 10 new tests (`CryptoRowsBuilderTests`) · 70 tests green (60 → 70) |
| M7 — Transactions screen | ✓ done (2026-05-21) | `TransactionsScreen` (`@Query` txns desc) · 3-card summary (Transactions YTD count + accounts · Net Inflows YTD = (sell+div+deposit)−(buy+withdraw), tone-tinted · Income YTD = div+stake) · 8 type pills (All + all 7 `TransactionType` cases — extends JSX's 5) · static "This month · MMMM yyyy" label + disabled Export stub · click-to-sort headers w/ chevron · per-row `TypeBadgeStyle` (buy=green, sell/withdraw=red, dividend=blue, stake=amber, deposit/transfer=neutral) · signed Total (+/− by type) tinted green for sell/dividend · `AccountBadge` per row · `···` overflow stub · footer w/ net total · USD-only `fxAt` until M10 · 8 new tests (`TransactionsRowsBuilderTests` — empty in-memory container, fixture-built txns w/ injectable `now`) · 78 tests green (70 → 78) |
| M8 — Overview MVP (chart-less) | ✓ done (2026-05-22) | `OverviewScreen` (`@Query` txns + quotes + settings) · 4 metric cards: Total Value (sub: "N positions across M accounts") · All-time Gain w/ % badge (sub: "Since MMM yyyy" from earliest txn) · YTD Performance honestly stubbed `—` "Available with M8.5" · Invested Capital (sub: "Cost basis across N accounts") · `OverviewChartCard` placeholder w/ visible `PeriodPills($range)` and centered 280pt empty state ("Chart available with M8.5") so M8.5 is a pure drop-in · `AllocationCard` w/ Stocks+Crypto split bar + legend rows (USD + %) backed by new `OverviewMetricsBuilder.allocation(holdings:baseCurrency:)` lumping stock+etf into Stocks · `AnnualPerformanceCard` reserves layout w/ column headers + "Historical comparisons available with M8.5" body · MacShell now routes `.overview` → `OverviewScreen` (was `PlaceholderScreen`) · 9 new tests (`OverviewMetricsBuilderTests` — earliest-date, positions count, accountsCount, allocation sums to 100, ordering, empty-state) · 87 tests green (78 → 87) |
| M8.5 — Real historical chart | ✓ done (2026-05-23) | New `HistoricalQuote` model (append-only, unique `(asset, source, day)` key; sibling of ephemeral `PriceQuote`) · Yahoo + CoinGecko + Mock `historical(symbol:range:)` implemented (Yahoo parameterized `chartURL` with range/interval + parses `timestamp[]`/`close[]`; CoinGecko `/coins/{id}/market_chart?days=N&interval=daily`, coarsened to UTC daily; Mock backward LCG walk) · FX historicals via `FXProvider.historical(from:to:range:)` reusing existing `FXRate` model · `QuoteRange` extended with `.ytd` + `.all`; `init?(pill:)` + `yahooRange` + `days(now:)` helpers · `HistoricalQuoteService` (`@Observable @MainActor`, lazy on first paint, idempotent — skips assets already covered to `floor`; stocks/FX parallel via `TaskGroup`, crypto serial with 1s spacing for CoinGecko rate-limit) wired into `FolioApp` env · `PortfolioHistoryReducer` (`@MainActor enum`, mirrors `HoldingsReducer` DI shape) walks txns chronologically and emits `[HistoryPoint]` for arbitrary date sets · `HistoricalLookups.priceOn`/`fxAt` do forward-fill via binary search (silent gap policy) · `OverviewChartCard` is now real Swift Charts (`LineMark` over series, `theme.blue` stroke, hover crosshair via `chartOverlay` + `onContinuousHover`, tooltip with date + value + delta-from-start, loading/empty states) · `OverviewScreen.task(id: range)` drives `HistoricalQuoteService.ensureLoaded` — daily series for ≤90d ranges, weekly stride otherwise · `OverviewSummary` YTD card now real (`PortfolioMetrics.ytdPerformance(history:)`, tone-tinted, sublabel "Since Jan 1, YYYY"; nil → "Available once history covers Jan 1") · `AnnualPerformanceCard` shows per-year rows from `AnnualPerformanceBuilder.rows(history:)` with BEST/WORST badges (S&P 500/Nasdaq cols intentionally `—` — benchmark tickers deferred to v2) · 27 new tests (PortfolioHistoryReducerTests × 7, HistoricalProviderURLTests × 10, AnnualPerformanceBuilderTests × 5, HistoricalQuoteServiceTests × 4, +1 Mock historical determinism test, –1 obsolete Mock-not-implemented test) · 114 tests green (87 → 114) · Smoke: launch → ⌘1 Overview → ProgressView → real chart renders within ~6–8s; SQLite shows 2510 yahoo + 1460 coingecko historical rows for 14 assets spanning May 2025 → May 2026 |
| M9 — Add Transaction flow | ✓ done (2026-05-26) | `AddTransactionSheet` replaces M2's stub · type-adaptive form (buy/sell/stake → asset+qty+price w/ auto-computed total · dividend → asset+amount · deposit/withdraw → amount only · transfer → source+destination accounts) · `AddTransactionForm` `@Observable @MainActor` w/ lenient `parseDecimal` (US `1,234.56`, EU `1234,56`, plain), enum `ValidationError` w/ user-facing `.message`, and `build()` → `PortfolioTransaction` · local-only `AssetPicker` over existing `Asset` rows, pre-filtered by account kind (brokerage → stock/etf · exchange/wallet → crypto) — live `QuoteProvider.search()` deferred to v2 per 2026-05-26 decision · txn currency follows `asset.currency` for trades / `account.currency` for cash events (read-only until M10) · FX preview row appears when txn.currency ≠ account.currency, sourced from latest cached `FXRate` (no network on open) · custom themed 520×640 sheet matching FolioTheme · ⌘N conflict still flagged for M10 (audit) · 17 new tests (`AddTransactionFormTests`) covering parsing, per-type validation, build outputs, currency derivation, type-adaptivity · 131 tests green (114 → 131) |
| M10 — Settings + polish | ☐ not started | |
| M11 — Test + verify | ☐ not started | |

Legend: ☐ not started · ◐ in progress · ✓ done · ✕ skipped/changed

---

## Toolchain (verified 2026-05-21)

- macOS 26 (Darwin 25.x), Apple Silicon
- Xcode 26.4 — Swift 6.3 toolchain · **Swift 6.0 language mode** with `SWIFT_STRICT_CONCURRENCY=complete`
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
| Over-sell policy | `HoldingsReducer` clamps sells at current qty (no negative-qty buckets, no shorts in MVP) — over-sized sells log a warning and the excess is dropped |
| PriceQuote dedupe | Refreshes within 60s of the last quote for the same (asset, source) update in place; older rows are preserved (historicals stay valid for M8) |
| Swift mode | Swift 6.0 language mode + `SWIFT_STRICT_CONCURRENCY=complete` (bumped 2026-05-21 during the pre-M5 audit — zero new diagnostics surfaced) |
| Overview chart | **Real historical** holdings × historical closes (option (a), resolved 2026-05-22). Implemented in a dedicated **M8.5** milestone after M8 ships chart-less. Snapshot approximation rejected (rewrites history); defer-to-v2 rejected (leaves a hole in the designed layout). |

---

## Open questions (do not block MVP)

- ~~**Overview chart strategy** — choose between (a) real historical (holdings × historical closes), (b) snapshot approximation (current holdings projected backward), (c) defer to v2. Plan ships Overview MVP **without** the chart; M8 leaves a layout slot.~~ **Resolved 2026-05-22:** (a) real historical, split into its own milestone **M8.5** so M8 stays focused on metrics + allocation + annual table. (b) rejected as dishonest (silently rewrites history with current holdings); (c) rejected because the prototype's Overview is designed around the chart slot.
- ~~**Quote refresh cadence** — proposed: on-launch + manual `⌘R` + 15-min foreground timer; revisit at M4.~~ **Resolved 2026-05-21:** on-launch + manual ⌘R + 15-min foreground timer (as proposed). Implemented in `QuoteRefreshCoordinator.startTimer(interval: 900)`.

---

## Audit follow-ups (deferred from M4.5)

Items surfaced by the 2026-05-21 pre-M5 review that were intentionally **not** fixed in the M4.5 commit — tagged with the milestone where they'll naturally come up. Strike through as each lands.

**Tackle during M5 (when touching this code anyway):**
- ~~`AppRouter.swift:5` — doc-comment references a non-existent `.environment(\.appRouter, …)` key path. Real injection is `.environment(router)` via `@Observable`. One-line fix.~~ **Done 2026-05-21** (M5).
- ~~`PlaceholderScreen.swift:26–32` — `switch Destination` has a `default` arm catching unreachable v2 destinations. Make exhaustive.~~ **Done 2026-05-21** (M5).
- `Folio/Sources/DesignSystem/Formatters.swift` — `FolioFormat` is dead in production (only `DesignSystemPreview` consumes it). Still dead after M5 (the Stocks screen formats via `Money.formatted()` + inline number/percent helpers in row views). Re-tag for M10 or inline into the preview.
- `SidebarItem.swift:53,61,65` — uses raw `Color.primary` / `.white` instead of theme tokens. Add `theme.hoverBg` + `theme.onAccent` or document the deviations. (Deferred — not touched in M5.)
- `MockQuoteProvider.swift:48–51,75` — `Decimal(string: "0.92")!` force-unwraps. Programmer-controlled literals, so won't crash, but worth tidying.
- ~~`SidebarFooter.swift:38–51` — recomputes the reducer on every body redraw.~~ **Stale**: SidebarFooter no longer hosts the reducer (it became refresh-status-only post-M4); item resolved by code change, not action.
- Empirically verify the `Holding.ID` stability fix once the Stocks table lands — `ForEach(\.id)` rows should keep selection/hover across `@Query` updates. **Verify next session** by hovering rows during a ⌘R refresh — hover state should not flicker.

**Tackle during M10 (settings + polish):**
- `MacShell.swift:49` — Add-holding bound to `⌘N`, conflicts with the macOS standard "New Window". Pick `⌘+` or `⌘⇧N`.
- `QuoteRefreshCoordinator.swift:135–142` — `Timer.scheduledTimer` keeps firing when the app is backgrounded or the window is closed. Observe `NSApplication.didBecome/ResignActive` to pause/resume.
- `SidebarFooter.swift:44` — FX closure hard-codes `from == to ? 1 : nil`. Wire a real FX closure that consults `FXRate` rows once the base-currency picker ships.
- `QuoteRefreshCoordinator.swift:121–128` — save-error catch swallows *any* error (disk full, schema migration) and still flips status to `.ok`. Filter to constraint-violation codes only; let the rest fail loudly.
- Replace `print(…)` in `HoldingsReducer.swift:81,100,107` and `QuoteRefreshCoordinator.swift:127` with `os_log`.
- Document `Money` mixed-currency `precondition` trap behavior in the type's doc-comment so callers know it's a programmer-error trap.

**Tackle during M11 (test + verify):**
- Add a `Money` precondition-trap test (or extract a public throwing variant for user-input paths and test that).
- Add an FX-pair de-duplication test in `QuoteRefreshCoordinatorTests` — `collectFXPairs` distinct-pair behavior is currently untested.
- Replace `MockQuoteProviderTests.testFXRateUSDEURRoundtripCloseToOne` — it asserts a property of hardcoded constants, not behavior.
- Synthetic seed dates (`2024-05-20` syntheticBuyDate vs `2026-05-x` mock txns) rely on sort order — brittle but currently correct. Note at M11.

**Defer to v2 (driven by future milestones):**
- `HoldingsReducer.swift:85` — ignores `txn.fee`. The Fees screen is v2 backlog; revisit then. Until then, inline-comment why the field is intentionally unused.
- `PortfolioMetrics.totalValue` — returns 0 for holdings with nil `marketValue`. Fine for MVP; consider a sibling `missingPriceCount` accessor for Overview empty-state UX.
- HTTP-layer 429 → `.rateLimited` mapping is untested (would require `URLProtocol` stubbing).
- `Money.formatted` falls back to a verbose form for ISO codes the locale doesn't recognize. Only exercised once non-USD ships.
- **(M8.5)** `AnnualPerformanceCard` S&P 500 / Nasdaq columns render `—`. Wiring real benchmarks needs an `Asset.isBenchmark` flag (or separate seed bucket) so SPY/QQQ historicals can be fetched without polluting holdings rollups in M5/M6/M8. Card subtitle reads "Yearly returns" until then.
- **(M8.5)** Dashed segments for forward-filled regions in the chart. Current policy is silent forward-fill via `HistoricalLookups`. Revisit once a real gap is observed in practice.
- **(M8.5)** Manual "Refresh history" affordance. Omitted because historicals are immutable; only needed if a provider returns bad data we'd want to overwrite.
- **(M8.5)** Intraday data points for the 1M view (current MVP serves daily granularity).

**Discuss when relevant:**
- `Money` mixed-currency math currently traps via `precondition`. Once M9 lets users enter non-base-currency transactions, decide whether to keep the trap or convert to throwing for user-input paths.
- `PortfolioMetrics` is `@MainActor`-isolated only because `Holding.asset.kind` crosses into a SwiftData model. Could split into a pure variant over precomputed `AssetKind` values if M11 tests find the actor coupling painful.
- `ContentView.swift` is now only referenced by its own `#Preview`. Keep as a preview canvas or delete and inline the previews into `DesignSystemPreview`?
- Hardcoded wallet/account hex colors are duplicated between `DesignSystemPreview.swift:76–80` and `SeedData.swift:140–148`. Extracting to a `BrandPalette.swift` would dedupe — worth doing once M5/M6 needs the same palette for badges.

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
    │   ├── Services/                          — QuoteProvider + FXProvider        [✓ M4]
    │   │                                        protocols, Mock/Yahoo/CoinGecko
    │   │                                        providers, QuoteRefreshCoordinator,
    │   │                                        HTTPClient
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

**Result (2026-05-21):** Shipped 7 new files under `Folio/Sources/Services/`: `QuoteProvider.swift` (protocol + `QuoteResult`/`QuoteRange`/`SymbolMatch`/`HistoricalPoint`/`QuoteProviderError`; declares `batchQuotes(symbols:)` with a fan-out default impl), `FXProvider.swift` (`FXResult` + `FXProviderError`), `HTTPClient.swift` (8s URLSession wrapper, `Folio/0.1` UA, 429→`.rateLimited`, decimal-safe number parsing via `decimalFromJSONNumber`), `MockQuoteProvider.swift` (LCG walk lifted from `data.jsx`; conforms to both protocols), `YahooQuoteProvider.swift` (quote+FX via `query1.finance.yahoo.com/v8/finance/chart/{sym}?interval=1d&range=1d`; `.`→`-` symbol fix for BRK.B; `historical`/`search` throw `.notImplemented`), `CoinGeckoQuoteProvider.swift` (overrides `batchQuotes` to single `simple/price?ids=a,b,c` call — fan-out per symbol was instantly rate-limited; symbol map points MATIC at `polygon-ecosystem-token` since the old `matic-network` id returns `{}` post-rebrand), `QuoteRefreshCoordinator.swift` (`@Observable @MainActor`; splits assets into stock/crypto specs by value before entering task groups so no `@Model` ref crosses the actor boundary; FX pair set computed from distinct (txn.currency, base) + (asset.currency, base) pairs; today's `FXRate.makeKey` makes refresh idempotent on the day; partial success → `.ok`, total failure → `.failed`). New UI: `Folio/Sources/Features/Shell/ToolbarRefreshStatus.swift` — compact button (8pt dot + monospace "Updated 2m ago" / "Refreshing…" / "Offline"; green/amber/red driven by status + 30-min staleness; click invokes `refreshAll`; ⌘R bound globally via `CommandGroup(after: .toolbar)` in `FolioApp`). `FolioApp` now owns the coordinator (`@State`), env-injects it, fires `.task { await refreshAll(); startTimer() }`. `SidebarFooter` rewritten to compute live total via `HoldingsReducer.reduceByAsset(...)` over `@Query` transactions; FX closure stays USD-only in M4 (cross-currency lights up in M10 when the base-currency picker ships). 11 new tests added (`MockQuoteProviderTests` × 6, `QuoteRefreshCoordinatorTests` × 5); 30 tests green. Smoke: `xcodebuild build` + `open Folio.app` → toolbar dot flips green within ~3s, sidebar footer shows live total (≈$580k at current quotes), DB has 10 `yahoo` + 6 `coingecko` `ZPRICEQUOTE` rows per refresh on top of the seed's 16. **Note:** SourceKit reported its usual cascade of "Cannot find type X in scope" errors during multi-file authoring; all cleared after `tuist generate` + `xcodebuild build` was real-green.

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

**Result (2026-05-21):** Shipped 7 new files under `Folio/Sources/Features/Crypto/` (`CryptoScreen.swift`, `CryptoSummary.swift`, `CryptoFilterBar.swift`, `CryptoRowsBuilder.swift`, `CryptoTable.swift`, `CryptoTableRow.swift`, `CryptoTableSubRow.swift`) + `Folio/Sources/DesignSystem/Components/CryptoLogo.swift`. Uses both `HoldingsReducer.reduceByAsset` (aggregate rows) and `.reduceByAssetAndAccount` (per-wallet sub-rows). Wallet pills are built by joining crypto-txn account names against the live `@Query private var accounts: [Account]` so the leading `Dot` colour comes straight from `Account.colorHex` (same source as `SeedData`'s palette). Expansion state lives in `CryptoScreen` as `@State expanded: Set<String>` keyed by ticker (default `["BTC", "ETH"]` per the JSX); when a wallet pill is active, `expandControlsEnabled = false` disables the Expand/Collapse buttons and `CryptoTable` hides both the chevron column content and the sub-rows. Staking YTD pulled into `CryptoRowsBuilder.stakingYTD(from:now:)` with an injectable `now` so the year-filter is testable (3 tests cover it). Subtitle line under the Staking metric lists the tickers (`ETH staking`) when amount > 0, otherwise "No rewards this year". One MainShell route added: `case .crypto: CryptoScreen()`. `MacShell.swift:30`. `xcodebuild build` + `test` both green (70 tests, was 60). App launches; toolbar dot turns green within ~3s; navigating ⌘2 → Crypto shows the 6 seeded coins with BTC default-expanded across Binance/Coinbase/Ledger. **Verify next session:** hover stability across ⌘R (same `Holding.id`-based `ForEach` as Stocks), and that sub-row dot colors match the active wallet-pill colour.

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
- **Reserved chart slot** in the layout — render a placeholder Card sized to the eventual chart so M8.5 is a pure drop-in. Include the PeriodPills control (1M / 3M / 6M / 1Y / All) wired to a `@State range` that M8.5 will read.

### M8.5 — Real historical chart
Spec: chart subtree in `project/overview.jsx`. Implements option (a) from the resolved open question — real holdings × historical closes, not snapshot approximation.

Scope:
- **Historical quote storage**: extend `PriceQuote` (or add a sibling `HistoricalQuote` entity if `PriceQuote`'s current `(asset, source, asOf)` shape becomes awkward — decide at implementation). Indexed by `(asset, date)`; daily granularity is enough for MVP.
- **Provider work**: implement `QuoteProvider.historical(symbol:, range:)` for Yahoo (`/v8/finance/chart/{sym}?interval=1d&range=...`) and CoinGecko (`/coins/{id}/market_chart?vs_currency=usd&days=...`). Both currently throw `.notImplemented`.
- **Historical FX**: extend `FXRate` queries to support a date param, or add `FXRate.historical(from:to:on:)`. Yahoo FX endpoint already supports historical via the same chart URL.
- **Time-series reducer**: new `PortfolioHistoryReducer` (sibling of `HoldingsReducer`) — walks transactions chronologically and, for each day in the requested range, emits `(date, totalValueInBase)`. Reuses `HoldingsReducer` state at each step. `@MainActor`, closure-injected price+FX lookups (same DI pattern as M3).
- **Refresh policy**: lazy fetch on first range selection; cache forever (historicals don't change). `QuoteRefreshCoordinator` does NOT eagerly refresh historicals — only current quotes. Add a manual "Refresh history" affordance only if it turns out to be needed.
- **Chart UI**: Swift Charts `LineMark` over the reducer's series. Theme-aware stroke. Hover crosshair shows date + value + delta-from-start. PeriodPills (1M / 3M / 6M / 1Y / All) drive `@State range`; the "All" pill spans from the earliest transaction date.
- **Edge cases**: missing historical closes (asset newly added, provider gap) → linear-interpolate forward from the last known close, with a subtle visual indicator (e.g. dashed segment) — alternative is to drop the day; decide once a real gap is observed.
- **Tests**: `PortfolioHistoryReducer` deterministic over a fixed transaction fixture + canned historical series; URL builders for both providers' historical endpoints; FX historical lookup.

Open sub-questions (resolved during M8.5 planning, 2026-05-23):
- ~~Where does the historical fetch get triggered — on first paint of Overview, or only on first PeriodPills interaction?~~ **First paint** — `OverviewScreen.task(id: range)` calls `ensureLoaded` for the current range; range changes re-trigger but the service is idempotent so only missing rows are fetched.
- ~~Are intraday data points needed for the 1M view, or is daily fine?~~ **Daily.** Implementation stridess weekly for ranges > 3 months to keep the chart responsive; daily for ≤ 3 months. CoinGecko's free-tier auto-coarsens past 90 days anyway.

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
