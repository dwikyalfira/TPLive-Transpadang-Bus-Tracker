# AGENTS.md

TPLive — Flutter bus tracker for TransPadang (Padang). See `README.md` for full detail.

## Repo layout
- This directory is the git repo root. Run **all** Flutter/git commands from here.
- Sibling folders at `K:\REP` (`padang/`, `_backup_transpadang/`, `_assets_logo_backup_*/`, root `*.apk`) are outside this repo — leave them alone.

## Toolchain (hard constraint)
- Flutter **3.19.6** / Dart **3.3.4**. Newer APIs break the build:
  - ❌ `Color.withValues`, `surfaceContainer*`, `WidgetState*` / `WidgetStatePropertyAll`, `CardThemeData` / `DialogThemeData`, `FadeForwardsPageTransitionsBuilder`.
  - ✅ Keep `withOpacity`, `surfaceVariant`, `MaterialStatePropertyAll`, `CardTheme`, `DialogTheme`.
- `withOpacity` is intentionally used here (not deprecated on 3.19). Do not "modernize" it.

## Commands
- Setup: `flutter pub get`
- Analyze: `flutter analyze` — baseline is **9 `info`** (2 `trans_ws_datasource.dart`, 1 `showStartEnd` in `halte_timeline_sheet.dart`, 6 generated l10n). Any new issue is a regression.
- Test: `flutter test` (77 tests). Single file: `flutter test test/home_tabs_test.dart`.
- Run: `flutter run -d <id>` (physical Android device, e.g. `a0d334d3` / model `2203129G`). `flutter run` stays attached; it does not exit.
- Localization: edit `lib/l10n/app_id.arb` (**template**) **and** `lib/l10n/app_en.arb`, then `flutter gen-l10n`. Generated `lib/l10n/app_localizations*.dart` are **tracked** — commit them too.
- Release: `scripts/build_release.ps1` (requires `dart_defines.json`, copy from `dart_defines.example.json`; that file is tracked and holds `MAPBOX_TOKEN`). Empty token → geocoding falls back to Nominatim.
- Assets: `scripts/generate_logo_assets.ps1`, then `dart run flutter_launcher_icons` / `dart run flutter_native_splash:create`.

## Architecture
- Entry `lib/main.dart`: `ProviderContainer` + `DynamicColorBuilder` + `MaterialApp(builder: RootOverlay)`.
- `lib/core/`: `config.dart` (all constants/URLs/hours), `settings.dart` (prefs), `follow_service.dart` (MethodChannel), `app_navigator.dart`, `theme/`, `ui/`.
- Features: `lib/features/<splash|tracking|trip|settings>/{data,domain,presentation}`.
- Theming is centralized in `lib/core/theme/app_theme.dart` (seed `#F47F38`). Add component styles there, not per-widget.
- Animation durations/curves live in `lib/core/theme/app_motion.dart` (`AppMotion.*`). Do not hardcode `Duration`/`Curve` in screens.
- Reuse the shared kit: `lib/core/ui/state_views.dart`, `lib/core/ui/fade_through_route.dart`, `lib/core/ui/constrained_content.dart` (centers + caps content width, already used by home/trip/settings), `features/tracking/presentation/widgets/corridor_badge.dart`. Do not re-add per-screen copies.
- Android native: `android/app/src/main/kotlin/id/dwiky/transpadang_live/` (`MainActivity.kt`, `FollowService.kt`, `HalteMath.kt`). MethodChannel `id.dwiky.transpadang_live/follow`. `applicationId`/`namespace` = `id.dwiky.transpadang_live`; `compileSdk 36`, `minSdk 21`.

## Domain quirks (already normalized — do not "fix")
- Server **swaps** `latitude`/`longitude`; normalized in `Bus.fromJson`.
- `last_update` is WIB (UTC+7), stored as UTC; buses older than 5 min are hidden.
- Operating hours 05:00–20:00 WIB (`AppConfig`); outside hours shows purple `0xFF7B1FA2`.
- Stop data is bundled (`assets/halte.json`, corridors K1–K6). No REST dependency.

## Gotchas that break things
- **`Tooltip` crashes outside the Navigator `Overlay`.** `PinnedBusOverlay` is mounted in `MaterialApp.builder`, outside the Navigator's `Overlay`, so `Tooltip` throws "No Overlay widget found". Use `Semantics(label: ...)` there instead (see `floating_pinned_bus_card.dart`).
- Widget tests build their own plain `MaterialApp` (not the app theme) and assert exact values. Changing these requires updating tests:
  - corridor tab icon is a `Container` with `constraints: maxWidth == 40`; unselected color = `corridorColor('K1').withOpacity(0.35)`.
  - outside-hours purple `Color(0xFF7B1FA2)`.
  - icons `Icons.close`, `Icons.my_location`, `Icons.arrow_downward`.
  - `FloatingPinnedBusCard.contentKey`; expanded card height `< 200`, collapsed `< 120`; `DraggableScrollableSheet` 0.5/1.0/min<0.5; settings has exactly one `SwitchListTile`.
- Every new UI string must be added to **both** ARB files or `flutter gen-l10n` / the app breaks.
