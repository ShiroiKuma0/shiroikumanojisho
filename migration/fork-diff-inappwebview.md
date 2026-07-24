# Fork audit: arianneorpilla/flutter_inappwebview @ ffd18243

Audited: 2026-07-24. Fork clone + upstream (pichillilorenzo/flutter_inappwebview) fetched into
`scratchpad/inappwebview/`.

## Base upstream version

- Merge-base of fork commit `ffd182431017ec919ece3f80bf5e22a9286189af` and `upstream/master`:
  `0157c8ec7cc1f45adf0b27adcea889f20deff483`, which is **exactly tag `v6.0.0-beta.25`** (2023-10-02).
- `pubspec.lock` in shiroikuma-jisho confirms: resolved version `6.0.0-beta.25`.
- The fork is therefore **upstream v6.0.0-beta.25 + exactly ONE commit**:
  `ffd18243 "Sync with v6"` (committed 2023-10-05, authored by lrorpilla). Despite the commit
  message, it is not a sync — it is the jidoujisho patch set rebased onto beta.25.

## Fork-only changes (the single commit, 2 files, +65/−10)

### Patch 1 — `PluginScriptsUtil.java`: rewritten `GET_SELECTED_TEXT_JS_SOURCE` (Android)

Replaces upstream's trivial `window.getSelection().toString()` with a DOM-walking implementation
that collects only `#text` nodes in the selection range and **filters out nodes whose parent (or
grandparent) is `<rt>` or `<rp>`** — i.e. `InAppWebViewController.getSelectedText()` returns the
selected Japanese text **without furigana ruby annotations**. It also handles start/end offsets of
partial node selections.

**Verdict: (b) behavior customization the app depends on — NOT in upstream.**
Checked upstream `v6.1.5` (`flutter_inappwebview_android/.../plugin_scripts_js/PluginScriptsUtil.java`):
still the plain `toString()` version. Also unchanged in the 6.2.0 betas' Android package.

App dependence is heavy: `getSelectedText()` is called at ~15 sites across
`lib/src/pages/implementations/reader_ttu_source_page.dart` (TTU reader — renders ruby
constantly), `browser_source_page.dart`, and `mokuro_catalog_browse_page.dart`. With stock
upstream, every selection over ruby text would include furigana readings inline and corrupt
dictionary lookups / card export.

### Patch 2 — `InAppWebView.java`: floating context menu X position

One-liner in `onFloatingActionGlobalLayout` / `updateViewLayout`:
`curx` → `curx + getScrollX()` (adds horizontal scroll offset when positioning the custom
floating context menu, matching the existing `getScrollY()` handling).

**Verdict: (a) obsolete — already in upstream.**
Upstream has the identical `curx + getScrollX()` at the same call site in **v6.0.0 stable and all
of 6.1.x** (checked `v6.0.0` and `v6.1.0`/`v6.1.5`,
`flutter_inappwebview_android/.../webview/in_app_webview/InAppWebView.java`, line ~1720).

## Structural note for migration

Upstream ≥ 6.0.0 stable restructured into a federated plugin: the Android code the fork patches
now lives in the separate `flutter_inappwebview_android` package
(`com.pichillilorenzo.flutter_inappwebview_android.*`). A rebased fork would have to fork that
sub-package (or the whole monorepo with a path dependency), not the old single-package layout.

## Recommendation

Move to upstream 6.1.x (latest tag `v6.1.5`) **without keeping a fork**, and reimplement the one
surviving patch at the app level:

1. Patch 2 (scrollX) needs nothing — upstream has it.
2. Patch 1 (furigana-stripping selection) should be ported into the app: the three page
   implementations already wrap the call in their own `getSelectedText()` helper, so replace the
   body with `controller.evaluateJavascript(source: <the fork's RT/RP-filtering JS>)` (extract the
   JS string from the fork commit; it is self-contained). That removes the git dependency
   entirely and keeps the behavior byte-identical, since the fork's change was only the JS payload
   sent to the page.
3. Alternative if an app-side port is unwanted: fork `flutter_inappwebview_android` at 6.1.5 and
   reapply only the `GET_SELECTED_TEXT_JS_SOURCE` hunk — a 1-file, ~60-line carry. But the
   app-side `evaluateJavascript` route is strictly simpler and survives future plugin upgrades.

Watch items when bumping beta.25 → 6.1.5: it crosses the 6.0.0-stable line (federated split,
several breaking API renames listed in upstream's 6.0.0 changelog), so expect Dart-side compile
fixes in the app beyond this fork question — but no fork-behavior loss other than item 1.
