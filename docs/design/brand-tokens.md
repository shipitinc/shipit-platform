# ShipIt Brand Tokens — Extracted from `Logo and Brand Guide Lines.png`

**Source of truth:** `Logo and Brand Guide Lines.png` (repo root, 2646 × 18406 px)
**Extraction method:** direct pixel sampling via PIL (not read from rendered label text — values are exact)
**Extracted:** 2026-09-15

> These are the authoritative brand values. Do not invent palettes. Any design work for
> ShipIt products must derive from this file.

---

## 1. Core palette

| Token | Hex | Role assigned in control-plane work |
|---|---|---|
| Brand yellow | `#FFF33B` | Warning / expiring |
| Brand red | `#E93E3A` | Failed / terminal |
| Brand mint | `#6FFFCE` | Success / passed |
| Brand blue | `#4496FC` | System acting / running |
| Brand orange (warm-ramp mid) | `#F7A42C` | Human authority required |
| Brand orange deep | `#F1813E` | Warm ramp step |

## 2. Background colours

| Token | Hex | Notes |
|---|---|---|
| Background warm | `#1F2120` | Near-black, warm. Used by Directions B and D |
| Background cool | `#222D35` | Charcoal blue. Used by Direction C |

## 3. Gradients

Both gradients are a **defining brand element**. Sampled stops:

**Warm gradient (yellow → red)**
```
#FFEC33 → #FCC210 → #F7A42C → #F1813E → #EA443A
```

**Cool gradient (mint → blue)**
```
#6EFDCF → #62E0DC → #56C3E8 → #4CA9F4 → #4497FC
```

> **Open finding:** none of the three current visual directions uses a gradient anywhere.
> The independent reviewer flagged this as a shared brand miss.

## 4. Typography

**Specified logotype:** `GoodTimesRg-Regular`

**Availability:** Good Times is a **commercial font and is NOT available in Penpot.**

**Substitute used in the direction study:** `Orbitron` (wide, geometric, squared — closest free analogue with a full weight range 400–900).

Reviewer verdict on the substitute:
- Acceptable **at wordmark size only**.
- Does **not** reproduce the logotype's oblique slant, so every header is subtly off-brand.
- **Production must import the real lockup as SVG from the brand kit — never set it as live text in a substitute face.**
- Direction D over-extends the display face into body prose, which costs legibility.

## 5. Logo assets

| File | Purpose |
|---|---|
| `assets/shipit-logomark-480.png` | Logomark, 480×490, background keyed to transparency |
| `assets/shipit-logomark-64.png` | Same mark at 64×65, used for the Penpot upload |
| `assets/brand-color-panel.png` | Crop of the guide's colour + typography panel, for verification |

**Penpot uploaded media id:** `c514c1fb-1cda-8125-8008-a48a2b732164` (64×65, `image/png`)

Logo application rules observed in the guide:
- Mark is used on approved dark fields (`#1F2120`, `#222D35`) and on light fields.
- The guide's "Incorrect Logo Application" panel shows flat/monochrome renderings — the mark **must retain its gradient**.

---

## 6. ACCESSIBILITY FINDING — unresolved, needs brand-owner decision

The official palette **falls just short of WCAG AA (4.5:1) for small text** on the brand
backgrounds. Originally reported as 52 instances across "18" study boards; **remeasured 2026-09-15 as 34 across the 16 boards that actually exist** (see study §7.1). Representative shortfalls:

| Foreground | Background | Measured ratio | Required |
|---|---|---|---|
| `#E93E3A` | `#1F2120` | 4.02 | 4.5 |
| `#4496FC` | `#2B3742` | 4.06 | 4.5 |
| `#E93E3A` | `#222D35` | ~4.1 | 4.5 |
| `#A35F00` (light-mode orange) | `#EFEFEC` | 4.35 | 4.5 |
| `#B36A08` (light-mode orange) | `#FAF8F2` | ~4.4 | 4.5 |

**These were deliberately NOT "fixed" by altering brand colours.** Options to present to the
brand owner:

1. Restrict brand hues in text to ≥18px, or ≥14px bold (where the 3.0:1 threshold applies —
   all brand colours pass at that size).
2. Use brand hues for non-text elements (ticks, bars, dots, fills) and pair with
   high-contrast neutral text for the label.
3. Commission a brand-sanctioned "accessible variant" of each status hue for small text.

Neutral (non-brand) text in the study **was** auto-corrected and now passes AA throughout.
