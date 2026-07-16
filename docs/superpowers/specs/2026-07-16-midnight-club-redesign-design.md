# khomasi redesign — "Midnight Club"

Date: 2026-07-16

## Brief

Redesign khomasi (خماسي — an Arabic-first, five-a-side football booking app for
the Iraqi community) so it reads like a good modern football app. The prior
look was the generic Flutter starter theme: `deepPurple` everywhere, grey
backgrounds, default system font — templated and unrelated to football.

## Direction: Midnight Club

Five-a-side under floodlights, rendered like a **premium matchday ticket** (not a
betting app). One confident color, gold used sparingly like metal trim, and a
"fixtures-board" voice for headline numbers. Dark-first; light polished too.

### Color tokens (`lib/theme/app_colors.dart` → `AppPalette`)

| Token | Dark | Light | Role |
|---|---|---|---|
| background | `#0C1416` | `#EFF3EF` | app bg (blue-green night / cool chalk — never cream) |
| surface | `#111C1E` | `#FFFFFF` | cards |
| emerald (primary) | `#12B886` | `#0E9E74` | the one color: CTAs, active, open matches |
| gold (accent) | `#C9A24B` | `#A9822E` | hairlines, rank #1, booked — metal trim, sparse |
| textHi | `#ECF1EC` | `#0C1416` | primary text |
| textMid | `#93A6A2` | `#55635F` | secondary text |
| onEmerald | `#06100E` | `white` | ink on the emerald CTA (dark on bright kit) |

Match-fill scale: **emerald (open) → gold (filling) → dim (full)** — replaces the
old red/orange/green traffic light.

### Type (bundled `.ttf`, `lib/theme/app_text.dart`)

- **Reem Kufi** — display & the "خماسي" wordmark (architectural Kufic).
- **IBM Plex Sans Arabic** — all UI/body; one voice across both scripts.
- **IBM Plex Mono** — headline numerals ONLY (price, rank, score, countdown):
  the "fixtures-board" voice. This is the deliberate design risk.

### Signature elements

1. **Matchday-ticket match card** — floodlit photo, gold hairline with punched
   ticket-notch, mono price, emerald roster-fill bar; booked → gold trim.
2. **Kufic wordmark under a floodlight glow** on login/signup.
3. **Leaderboard medals** — gold #1 / silver #2 / bronze #3, mono stats.

## Implementation

- `lib/theme/app_colors.dart`, `app_text.dart`, `app_theme.dart` (new). Theme
  exposes semantic colors via the `AppPalette` `ThemeExtension` (`context.palette`)
  and wires every component theme (buttons, inputs, chips, nav, dialogs, …).
- `theme_provider.dart` rewired to `AppTheme.light()/dark()`; toggle API unchanged.
- `pubspec.yaml`: bundled fonts under `assets/fonts/` (no `google_fonts` runtime dep).
- Hand-restyled: `match_card`, `my_button`, `my_wide_button`, `my_textfield`,
  `root_page` (app bar + floating pill nav), `login_page`, `signup_page`,
  `leaderboard_page`.
- Global sweep: 273 `Colors.deepPurple*` refs across 31 files → centralized brand
  tokens (`AppColors.brand` / palette). 0 remaining. `flutter analyze`: 0 errors.

### Preview harness

`test/design_preview.dart` renders the redesigned widgets with the real fonts in
Arabic RTL. Regenerate PNGs (not run in CI):

```
flutter test test/design_preview.dart --update-goldens
# → test/goldens/preview_dark.png, preview_light.png
```

## Remaining (optional polish)

Secondary screens inherit the new theme (bg, cards, fonts, buttons, nav) via the
sweep, but a few still carry hardcoded greys / `Color(0xFF1F1F1F)` surfaces worth
a palette pass: `profile_page`, `booking_page`, `settings_page`, `referee_page`,
`match_chat_page`, `match_history_page`, `edit_profile_page`, `active_match_page`.
