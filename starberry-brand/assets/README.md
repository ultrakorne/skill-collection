# StarBerry Brand Assets

This directory contains StarBerry logo files and brand templates.

## Available Assets

### Logo Files (PNG Format)

All logos are organized in subdirectories by mark type and include multiple variations for different use cases.

#### Primary Mark (logos/primary/)
- `StarBerry_Primary_Mark_Positive.png` - Color version for light backgrounds
- `StarBerry_Primary_Mark_Reverse.png` - Color version for dark backgrounds
- `StarBerry_Primary_Mark_Grayscale.png` - Grayscale version for light backgrounds
- `StarBerry_Primary_Mark_Grayscale_Reverse.png` - Grayscale version for dark backgrounds
- `StarBerry_Primary_Mark_1-Colour.png` - Single color (black) version
- `StarBerry_Primary_Mark_1-Colour_Reverse.png` - Single color (white) version

**Usage**: Office entrance signage, app splash/load screens, document covers, business card covers, slide presentation covers, phone case covers

**Minimum size**: 70px / 25mm
**Clearspace**: 2 × B on all sides

#### Secondary Mark (logos/secondary/)
- `StarBerry_Secondary_Mark_Positive.png` - Color version for light backgrounds
- `StarBerry_Secondary_Mark_Reverse.png` - Color version for dark backgrounds
- `StarBerry_Secondary_Mark_Grayscale.png` - Grayscale version for light backgrounds
- `StarBerry_Secondary_Mark_Grayscale_Reverse.png` - Grayscale version for dark backgrounds
- `StarBerry_Secondary_Mark_1-Colour.png` - Single color (black) version
- `StarBerry_Secondary_Mark_1-Colour_Reverse.png` - Single color (white) version

**Usage**: Website mastheads, email signatures, business card backs, PowerPoint template headers, wristbands, bicycle frame wraps

**Minimum size**: 100px / 35mm
**Clearspace**: 2 × B on left and right, 1 × B above and below

#### Tertiary Mark (logos/tertiary/)
- `StarBerry_Tertiary_Mark_Positive.png` - Color version for light backgrounds
- `StarBerry_Tertiary_Mark_Reverse.png` - Color version for dark backgrounds
- `StarBerry_Tertiary_Mark_Grayscale.png` - Grayscale version for light backgrounds
- `StarBerry_Tertiary_Mark_Grayscale_Reverse.png` - Grayscale version for dark backgrounds
- `StarBerry_Tertiary_Mark_1-Colour.png` - Single color (black) version
- `StarBerry_Tertiary_Mark_1-Colour_Reverse.png` - Single color (white) version

**Usage**: General office signage, t-shirts, office mugs, animated masks within games or video, printed material emboss details, cappuccino stencils

**Minimum size**: 30px / 10mm
**Clearspace**: Half the height or width of the central shape (not including leaf element)

### Favicons (favicons/)

Pre-generated favicon files from the Tertiary Mark, square-padded with transparent backgrounds. Ready to copy directly into your project.

- `favicon.ico` - 32×32, standard browser favicon
- `apple-touch-icon.png` - 180×180, iOS home screen icon
- `favicon-192.png` - 192×192, PWA icon
- `favicon-512.png` - 512×512, PWA splash icon

**Usage**: Copy to your project's public/static assets directory. No ImageMagick required.

#### Web-Sized Secondary Mark (logos/secondary/web/)

Pre-resized versions of the Secondary Mark optimized for website headers (112px height, retina-ready for `h-7` / 28px display).

- `StarBerry_Secondary_Mark_Positive_web.png` - For light backgrounds
- `StarBerry_Secondary_Mark_Reverse_web.png` - For dark backgrounds

**Usage**: Copy to your project's static assets directory and reference in header `<img>` tags.

### Templates (templates/)

#### Presentation Template (templates/presentations/)
- `ppt_template.pptx` - PowerPoint presentation template with StarBerry branding
  - Includes branded cover slide with Primary mark
  - Content slides with Secondary mark in header
  - Proper color palette and typography applied
  - Ready to use for company presentations

## File Format Notes

### PNG Files
- All logos provided as PNG with transparent backgrounds
- Suitable for both digital and print use
- Recommended resolution: 300 DPI for print, 144 DPI for high-quality digital

## Logo Selection Guide

### Choose by Background Color

**Light/White Backgrounds:**
- Use `*_Positive.png` versions
- Or `*_Grayscale.png` versions for grayscale needs
- Or `*_1-Colour.png` (black) for single-color printing

**Dark Backgrounds:**
- Use `*_Reverse.png` versions
- Or `*_Grayscale_Reverse.png` for grayscale needs
- Or `*_1-Colour_Reverse.png` (white) for single-color printing

### Choose by Application

**Full Color Available:**
- Use Positive or Reverse versions (full brand colors)

**Grayscale/Black & White Printing:**
- Use Grayscale versions (maintains tonal values)

**Single Color Printing/Embossing:**
- Use 1-Colour versions (pure black or white)

## Usage Guidelines

### DO:
- Use logos at or above minimum sizes specified above
- Maintain proper clearspace around all marks
- Select appropriate version for your background color
- Use the provided PowerPoint template for presentations
- Reference the main SKILL.md for complete brand guidelines

### DO NOT:
- Resize logos below minimum dimensions
- Alter the logo colors or apply filters
- Stretch, distort, or rotate the logos
- Place logos on busy or low-contrast backgrounds
- Add effects like shadows, strokes, or glows to logos
- Separate logo elements

## File Organization

```
assets/
├── favicons/           (Pre-generated favicon files)
├── logos/
│   ├── primary/        (6 variations of Primary Mark)
│   ├── secondary/      (6 variations of Secondary Mark)
│   │   └── web/        (Pre-resized for web headers)
│   └── tertiary/       (6 variations of Tertiary Mark)
└── templates/
    └── presentations/  (PowerPoint template)
```

## Additional Resources

For complete brand guidelines including color codes, typography specifications, and usage examples, see:
- `/references/colors.md` - Detailed color palette specifications
- `/references/typography.md` - Typography rules and examples
- `/references/usage-examples.md` - Practical application guidance
- `/SKILL.md` - Core brand guidelines overview
