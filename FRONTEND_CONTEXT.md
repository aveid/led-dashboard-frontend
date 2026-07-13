# CONTEXT: Flutter Frontend
# Rules:
# 1. NO codegen. freezed/json_serializable forbidden — manual fromJson/toJson/copyWith only.
# 2. NO fpdart. Use the project's own sealed Result<Failure, T>.
# 3. Clean Architecture (feature-first): presentation -> domain <- data. domain is pure Dart.
# 4. Riverpod: never name custom Notifier/AsyncNotifier methods `update`, `state`, `future`, or
#    `ref` — they collide with base-class members and fail to compile.

## 1. Stack
- Dart 3 / Flutter. Runs on Web and mobile from one codebase — gestures are written cross-platform
  (right-click on web = long-press on mobile, same handler).
- State/DI: Riverpod (`flutter_riverpod`). Navigation: `go_router`.
- Network: `dio`, global instance + JWT bearer interceptor. `401` → clear token, redirect `/login`.
  `403` → mapped to `ForbiddenFailure`, does not log out (defense-in-depth, not an auth failure).
- Map: `flutter_map` + OSM tiles, markers colored by `ScreenStatus`. Clustering via
  `flutter_map_marker_cluster` (its major version must match `flutter_map`'s).
- Media: `url_launcher` for non-image attachments; images use built-in `InteractiveViewer` for zoom.
- Files: `file_picker` (`withData: true` — Web has no filesystem path).

## 2. Directory Layout
- `lib/core/`: `theme/`, `network/`, `router/`, `error/` (`failure.dart`, `result.dart`), `utils/`.
- `lib/shared/`: cross-feature widgets + domain (`Money`, `ScreenStatus`, `LandlordCost`).
- `lib/features/`: `auth`, `users` (RBAC), `map_dashboard` (map/markers/selection), `screens`
  (card/forms/attachments), `landlords`, `campaigns`, `cities`, `screen_types`.
- Each feature: `domain/` (entities, ports) | `data/` (DTOs, datasources, repo impl) |
  `presentation/` (pages, widgets, providers).

## 3. Map (`map_dashboard`)
- Markers colored by `ScreenStatus`; clustered via `MarkerClusterLayerWidget` — the cluster bubble
  itself is neutral/brand-colored + a count (not status-colored, since a cluster can mix
  statuses), individual markers keep their status color. Tap on a single marker → `ScreenCardSheet`.
- **Location is set entirely by gesture — there is no manual lat/lng field anywhere.** Right-click
  (web) / long-press (mobile) on empty map → context menu "Добавить экран" →
  `ScreenFormDialog(initialLocation:)`. Same gesture on an existing marker → "Поменять локацию" →
  center-pin relocation mode (fixed pin at map center, pan to reposition, pinned bottom
  Save/Cancel bar) → `PATCH /api/screens/{id}/location`. The marker's own `GestureDetector` uses
  `HitTestBehavior.opaque` to consume the secondary-tap so the map's own handler doesn't also fire.
- **Box-select (Shift+drag, web/desktop only):** rubber-band selection via the camera's reverse
  projection (`offsetToCrs`) against raw screen coordinates (so it also catches screens hidden
  inside clusters) → adds to the same `selectedScreenIdsProvider` (`Set<String>`) used by
  pick-mode and Shift+click. While Shift is held, map pan/rotate/fling are disabled via
  `InteractionOptions.flags` so the drag doesn't pan the map; the overlay itself is
  `HitTestBehavior.translucent`. Feeds the same `CostSummaryPanel` (count, clear, Excel export).
- **Kyrgyzstan-only bounds (FR-1.6) — spec only, not built:** planned `CameraConstraint.contain`
  + a dim mask (`PolygonLayer` world-with-a-hole + `PolylineLayer` outline, placed below
  markers/clusters, non-hit-testing so gestures pass through) fed once by `kgBoundaryProvider` →
  `GET /api/geo/kyrgyzstan`. Coordinate order from the backend is `[lng, lat]` — swap to
  `LatLng(lat, lng)` at the boundary.

## 4. Screens feature
- `ScreenFormDialog` (create/edit): **`active` is never a selectable status** — the only path
  into `active` is the dedicated Activate flow. Exception: editing an already-active screen
  keeps its current status as an option (so editing doesn't force a downgrade). This restriction
  exists because the backend does not enforce the activation invariant on plain create/PATCH,
  only inside the dedicated activate path — this is the only thing preventing bypass from the
  form. Default status on create is `potential`.
- `ActivateScreenDialog`: price + start/end date. The real gate (photo + landlord + price + date)
  is server-side — a 409 here shows the backend's message as-is, not a client-side guess.
- `rentalEndDate` (nullable date) lives on the form (date-picker, clearable via an explicit
  "Очистить", not just leaving it blank) and on `ScreenCardSheet` ("Аренда до …", hidden if null;
  a cosmetic "Истекает скоро" chip appears if active and due within 7 days — client-side only,
  actual archiving is the backend's lazy sweep, the client just refetches on the next read).
- Attachments: `ScreenCardSheet` renders real previews from the presigned `url` (images
  inline+zoom, PDF/other as an "Open" link) — not a placeholder badge. Upload buttons are inline
  per section with a fixed type each (photo/contract), disabled past `kMaxAttachmentsPerKind = 5`
  (mirrors the backend cap) with a tooltip explaining why. Each attachment has its own delete
  control with a confirm dialog. Media GETs hit the presigned URL directly, bypassing `dio`
  entirely (no JWT needed); delete goes through `dio` (JWT required).
- No district/street/manual-coordinate fields anywhere (see Map §3 — location is gesture-only).

## 5. Landlords
- `LandlordCard` is an `ExpansionTile` that lazy-loads `GET /api/landlords/{id}/screens` on first
  expand (`FutureProvider.family`). Shows "Экранов: N" plus a `Σ` total, both computed client-side
  from the loaded brief list — there is no server-side aggregate for either.

## 6. RBAC (NFR-8)
- Three roles surfaced on the frontend: `admin`, `user`, `guest`. Source of truth is
  `GET /api/auth/me`, fetched right after login into `currentUserProvider`. `isAdminProvider` /
  `isGuestProvider` (both fail-safe to `false` while loading or on error) are the only places UI
  should branch on role — don't re-derive role logic elsewhere.
- Masking is UX, not security — the backend is authoritative and returns 403 on any disallowed
  write. Non-admin: every write control is hidden (`AdminOnly` wrapper or an inline `if`); the
  `/users` route is guarded in the `app_router` redirect.
- `guest` additionally: hides the "Документы/Договор" section on `ScreenCardSheet` (photos still
  show) and the entire Dashboard nav item/route; renders every price through a single
  `guestPriceText()` helper (blank for guest, blank if the underlying value is `null`, else
  `formatSom`) rather than calling `formatSom()` directly at each price call site.
- `403` never triggers logout — only `401` does, and only via the `dio` interceptor.

## 7. UI Rules
- Tap targets ≥ 48px: inputs, buttons, marker tap areas, context-menu items, delete controls.
- Bottom sheets for entity detail (`ScreenCardSheet`); center dialogs for forms/inputs; relocation
  mode uses a pinned bottom action bar, not a sheet.
