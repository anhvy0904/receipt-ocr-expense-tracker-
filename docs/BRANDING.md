# ReceiptWise branding

User-selected palette: navy `#425B9A`, sky `#76C0EC`, cream `#FFF6DC`, pink
`#FF95A5`. Light mode uses cream surfaces, navy primary actions, sky containers
and pink navigation highlights. Dark mode uses navy-derived surfaces and bright
sky/pink accents. Ink and derived neutral shades preserve text contrast; error
colors retain their semantic meaning. Camera overlays keep their readable
white-on-dark treatment.

The logo is an original smiling receipt with pink cheeks, receipt lines and a
check badge. Built-in image_gen generated the transparent PNG. The original
asset is `assets/branding/receiptwise_logo.png`; Home displays it through
ReceiptWiseLogo. Android launcher icons are raster exports on a cream background.
No image generation or network call happens in the installed application.

Final generation prompt:

> Use case: logo-brand. Asset: ReceiptWise mobile expense tracker mascot logo,
> one standalone square logo on true transparent background. Create an adorable
> smiling cream receipt character with rounded corners, a short zigzag paper
> bottom, two tiny navy eyes, pink blush cheeks and a friendly smile. Three simple
> blue receipt lines at top suggest scanned purchases; a small sky-blue check
> badge at lower right communicates verified expenses. Flat clean vector-like
> illustration with bold smooth navy outlines, very readable at app icon sizes,
> centered with generous 18% clear padding. Palette strictly navy #425B9A, sky blue
> #76C0EC, warm cream #FFF6DC, pink #FF95A5. No text, no lettering, no watermark,
> no gradients, no shadows, no extra objects. Cute calm helpful personality,
> polished original brand mark.

To regenerate launcher exports without changing the source logo:

```text
dart run tool/generate_brand_icons.dart
```

Changed/new files: brand_colors.dart, app_theme.dart, receiptwise_logo.dart,
home_screen.dart, category_donut_chart.dart, pubspec.yaml, this document, source
logo, five Android mipmap launcher icons, export tool, README and refreshed UI
screenshots. OCR, parser, camera, database and repository logic remain unchanged.

Verification: dart format, flutter pub get, flutter analyze (no issues), flutter
test (96 passed), host-rendered light/dark/review/history/analytics screenshots,
release build (1.1.1+4) and successful apksigner verification. Main text pairs
navy/cream, ink/sky, ink/pink and muted/cream have contrast ratios above 6:1.
Physical Android launcher/theme checks remain TODO; native OCR/device/video
acceptance items in COURSE_READINESS.md still apply.
