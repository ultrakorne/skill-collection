# StarBerry Web Theming Guide

Ready-to-use theme definitions for **StarBerry internal tools and company websites** using Tailwind CSS + daisyUI. This is NOT for games or products made by StarBerry — those have their own branding. Use this guide when building internal tools, admin dashboards, or StarBerry company-facing web apps.

## Font Setup

Import Source Sans Pro and set as default sans font:

```css
@import url('https://fonts.googleapis.com/css2?family=Source+Sans+Pro:ital,wght@0,400;0,700;0,900;1,400&display=swap');

@theme {
  --font-sans: 'Source Sans Pro', Arial, sans-serif;
}
```

## daisyUI Theme Definitions (oklch)

### Light Theme

```css
@plugin "../vendor/daisyui-theme" {
  name: "light";
  default: true;
  prefersdark: false;
  color-scheme: "light";
  --color-base-100: oklch(98.5% 0.006 60);       /* warm off-white */
  --color-base-200: oklch(95.5% 0.014 60);        /* subtle warm gray */
  --color-base-300: oklch(91% 0.020 60);           /* light warm border */
  --color-base-content: oklch(38.44% 0.059 258.93); /* Rhino #304463 */
  --color-primary: oklch(74.70% 0.162 44.65);     /* Coral #FF874E */
  --color-primary-content: oklch(100% 0 0);        /* white */
  --color-secondary: oklch(51.33% 0.066 283.82);  /* Kimberly #62628C */
  --color-secondary-content: oklch(98% 0 0);
  --color-accent: oklch(38.44% 0.059 258.93);     /* Rhino #304463 */
  --color-accent-content: oklch(98% 0 0);
  --color-neutral: oklch(45% 0.050 258);           /* Rhino lighter */
  --color-neutral-content: oklch(98% 0 0);
  --color-info: oklch(51.33% 0.066 283.82);       /* Kimberly */
  --color-info-content: oklch(97% 0.010 280);
  --color-success: oklch(73.29% 0.188 134.57);    /* Sushi #72C134 */
  --color-success-content: oklch(98% 0.014 135);
  --color-warning: oklch(74.70% 0.162 44.65);     /* Coral */
  --color-warning-content: oklch(38.44% 0.059 258.93); /* Rhino */
  --color-error: oklch(60.19% 0.165 30.17);       /* Valencia #D15140 */
  --color-error-content: oklch(96% 0.015 30);
  --radius-selector: 0.25rem;
  --radius-field: 0.25rem;
  --radius-box: 0.5rem;
  --size-selector: 0.21875rem;
  --size-field: 0.21875rem;
  --border: 1.5px;
  --depth: 1;
  --noise: 0;
}
```

### Dark Theme

```css
@plugin "../vendor/daisyui-theme" {
  name: "dark";
  default: false;
  prefersdark: true;
  color-scheme: "dark";
  --color-base-100: oklch(29.29% 0.045 254.30);   /* Cloud Burst #1C2D42 */
  --color-base-200: oklch(25% 0.038 254);          /* darker Cloud Burst */
  --color-base-300: oklch(34.28% 0.054 253.37);   /* lighter Cloud Burst */
  --color-base-content: oklch(95.21% 0.030 59.24); /* Papaya Whip #FFEBDC */
  --color-primary: oklch(74.70% 0.162 44.65);     /* Coral #FF874E */
  --color-primary-content: oklch(29.29% 0.045 254.30); /* Cloud Burst */
  --color-secondary: oklch(51.33% 0.066 283.82);  /* Kimberly #62628C */
  --color-secondary-content: oklch(95.21% 0.030 59.24); /* Papaya Whip */
  --color-accent: oklch(95.21% 0.030 59.24);      /* Papaya Whip */
  --color-accent-content: oklch(29.29% 0.045 254.30); /* Cloud Burst */
  --color-neutral: oklch(40% 0.050 260);           /* Kimberly darker */
  --color-neutral-content: oklch(95.21% 0.030 59.24); /* Papaya Whip */
  --color-info: oklch(51.33% 0.066 283.82);       /* Kimberly */
  --color-success: oklch(73.29% 0.188 134.57);    /* Sushi */
  --color-error: oklch(60.19% 0.165 30.17);       /* Valencia */
  --radius-selector: 0.25rem;
  --radius-field: 0.25rem;
  --radius-box: 0.5rem;
  --size-selector: 0.21875rem;
  --size-field: 0.21875rem;
  --border: 1.5px;
  --depth: 1;
  --noise: 0;
}
```

## Brand Color → Semantic Token Mapping

| Brand Color | Hex | Light Theme Token | Dark Theme Token |
|---|---|---|---|
| Coral | #FF874E | `primary`, `warning` | `primary` |
| Kimberly | #62628C | `secondary`, `info` | `secondary`, `info` |
| Rhino | #304463 | `base-content`, `accent`, `neutral` | — |
| Cloud Burst | #1C2D42 | — | `base-100`, `primary-content`, `accent-content` |
| Papaya Whip | #FFEBDC | — | `base-content`, `accent`, `neutral-content` |
| Sushi | #72C134 | `success` | `success` |
| Valencia | #D15140 | `error` | `error` |

### Light theme base tones

The base colors use very low chroma (0.006–0.020) on hue 60 (warm) to give a subtle branded warmth without looking obviously beige. This keeps cards/rows and backgrounds visually distinct while staying neutral.

## Logo in Headers

Use the Secondary Mark for website headers with light/dark mode switching. Pre-resized web versions (112px height, retina-ready for `h-7` / 28px display) are available in `assets/logos/secondary/web/`.

Copy the web-sized logos to your project's public/static assets directory, then add to your header:

**HTML:**
```html
<a href="/" class="flex items-center gap-2.5">
  <img src="/images/StarBerry_Secondary_Mark_Positive_web.png" alt="StarBerry" class="h-7 dark:hidden" />
  <img src="/images/StarBerry_Secondary_Mark_Reverse_web.png" alt="StarBerry" class="hidden h-7 dark:block" />
</a>
```

**React / JSX:**
```jsx
<a href="/" className="flex items-center gap-2.5">
  <img src="/images/StarBerry_Secondary_Mark_Positive_web.png" alt="StarBerry" className="h-7 dark:hidden" />
  <img src="/images/StarBerry_Secondary_Mark_Reverse_web.png" alt="StarBerry" className="hidden h-7 dark:block" />
</a>
```

**Source files:** `assets/logos/secondary/web/StarBerry_Secondary_Mark_Positive_web.png` and `StarBerry_Secondary_Mark_Reverse_web.png` (pre-resized to 112px height).

> **Note:** If you need a different size, the full-resolution source PNGs (3000px wide) are in `assets/logos/secondary/`. Resize with: `magick source.png -resize x<height> output.png`

## Favicon

Pre-generated favicons are available in `assets/favicons/`. Copy them to your project's public/static assets directory.

**Included sizes:**
- `favicon.ico` — 32×32, square-padded with transparent background
- `apple-touch-icon.png` — 180×180
- `favicon-192.png` — 192×192 (PWA)
- `favicon-512.png` — 512×512 (PWA)

**HTML tags to add in `<head>`:**
```html
<link rel="icon" href="/favicon.ico" sizes="32x32" />
<link rel="icon" href="/images/favicon-192.png" type="image/png" sizes="192x192" />
<link rel="apple-touch-icon" href="/images/apple-touch-icon.png" />
```

> **Note:** These are generated from the Tertiary Mark (star icon). The source is not square (2000×1620), so the favicons are square-padded with a transparent background to avoid distortion. To regenerate from source, use ImageMagick:
> ```bash
> magick source.png -resize 32x32 -background none -gravity center -extent 32x32 favicon.ico
> ```

## Hardcoded Color Replacements

When theming an existing app, replace any hardcoded Tailwind colors with semantic daisyUI tokens:

| Hardcoded | Replace with | Use case |
|---|---|---|
| `text-green-500` | `text-success` | positive actions (confirm, approve) |
| `text-red-500` | `text-error` | negative actions (cancel, delete) |
| `hover:bg-blue-600/80` | `hover:bg-primary/80` | primary action overlays |
| `hover:bg-purple-600/80` | `hover:bg-secondary/80` | secondary action overlays |
| `hover:bg-green-600/80` | `hover:bg-success/80` | success action overlays |
| `hover:bg-red-600/80` | `hover:bg-error/80` | destructive action overlays |
| `bg-black/50` | `bg-black/50` | keep as-is (functional overlay) |
| `#8c43ff` (purple) | `#62628C` | Kimberly brand color |

## Page Title

```
default="App Name" suffix=" · StarBerry"
```

## Checklist for New Projects

1. Copy web-sized Secondary Mark PNGs from `assets/logos/secondary/web/` to your static assets directory
2. Copy favicon files from `assets/favicons/` to your static assets directory
3. Add Google Fonts import for Source Sans Pro
4. Set `--font-sans` in `@theme` block
5. Replace daisyUI theme blocks with StarBerry colors (above)
6. Update header to use logo `<img>` tags with dark mode switching
7. Update page title suffix to `· StarBerry`
8. Add favicon `<link>` tags to `<head>`
9. Search & replace hardcoded colors with semantic tokens
10. Verify both light and dark themes visually

### Framework-specific notes

**React (Vite / Next.js / CRA):**
- Place logos and favicons in `public/` or `public/images/`
- For Next.js, place `favicon.ico` in `app/` or `public/`
- Use `className` instead of `class` in JSX
- For dark mode, ensure your app supports the `dark` class on `<html>` (e.g., via `next-themes` or a manual toggle)

**Phoenix / Elixir:**
- Place logos and favicons in `priv/static/images/`
- Use `~p"/images/..."` path helpers in `.heex` templates
- Phoenix LiveView apps with daisyUI typically configure themes in `assets/css/app.css`
