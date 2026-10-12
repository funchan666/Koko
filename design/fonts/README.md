# Koko bundled typography

A compact, warm social-app pairing: readable conversational text, confident
geometric headings and an occasional handwritten conversation prompt.

| Family | Original files | Use |
| --- | --- | --- |
| Nunito Sans | Regular / Medium / SemiBold | Body text, captions, names, fields and controls |
| Outfit | Bold | Headings, strong labels and numeric emphasis |
| Caveat | Bold | Two icebreaker question treatments only; never form controls or legal text |

Five unmodified static TTF files total 805,396 bytes (about 0.8 MB). No converted,
subsetted or generated glyphs. Fonts were downloaded from the authors' upstream
repositories at pinned commits on 2026-10-12. Exact URLs, PostScript names, weights
and SHA-256 hashes are recorded in font-provenance.json.

## Original sources and licenses

- Nunito Sans: https://github.com/googlefonts/NunitoSans
- Outfit: https://github.com/Outfitio/Outfit-Fonts
- Caveat: https://github.com/googlefonts/caveat

All three are SIL Open Font License 1.1. Each original copyright notice and license
is preserved beside the fonts and included in the application folder resource.
These are licensed third-party typefaces, not Koko-authored font designs.

## Loading and language behavior

project.yml includes this directory as a folder resource. UIAppFonts registers
Fonts/<filename>.ttf at application launch. KokoTypography uses the original
PostScript names, rather than relying on filenames or platform-installed Avenir.
There is no runtime font download or registration request to an external service.
The root body font and 366 native font references now use the local font system.
Dynamic Type relative text styles are retained. The two pre-scaled account
headlines use fixedSize to avoid applying scaling twice.

Latin characters used in English, Spanish and French interface translations are
covered by the regular body font. Chinese, Japanese, other unsupported glyphs and
symbols use iOS's on-device fallback fonts. No large CJK bundle is included.
Apple authorization, permission and payment sheets retain genuine system fonts.

The existing allowlisted terms/privacy reading style supplies local font data to
WKWebView with embedded data URLs. Original remote documents, text and links stay
unchanged. Site CSP may reject embedded font data; in that case the reader keeps
its local sans-serif fallback. Remote documents themselves still need network
access; this change makes only the font resources local.

## Verification

Static checks only: TTF table/metadata inspection, checksum matching, PostScript
name-to-UIAppFonts mapping, local Latin glyph coverage, resource/source references,
Info.plist/project plist syntax and Git whitespace checks. Project regenerated
with XcodeGen. No compilation, tests, analyzer, simulator, device run or rendered
visual acceptance was performed. Font metrics and localized wrapping still need
runtime review when explicitly requested.
