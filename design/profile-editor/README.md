# Koko profile editor

Native SwiftUI form refresh for the horizontally overflowing profile editor. Garden / GPT Image 2 Host-Native and the built-in image generator produced five dedicated raster assets. Taste, Claude Design and browser-oriented Garden skills were evaluated without forcing a web implementation into this native screen.

## Layout

The viewport explicitly bounds the page and scroll content. Form width is the window width minus 40 points, capped at 460 points. The wallpaper lives only in a background layer, with its rendered dimensions bounded to the viewport, so its intrinsic image size cannot widen the form. Navigation and the bottom action remain outside the scrolling fields. Container safe-area insets and keyboard resizing continue through KokoScreenCanvas.

A quiet petrol backdrop replaces the busy constellation image. One centered portrait leads into compact, independently illustrated library and camera actions. Mint selection surfaces and dark input surfaces have native localized text. Accessibility text sizes switch photo actions, choice grids and birthday inputs to vertical layouts. Field focus scrolls to the active input, and page changes scroll to the heading.

## Artwork

Five original generated PNGs are copied unchanged into both `assets/original-ui/profile-editor/` and KokoArtwork.xcassets. Full prompts and source SHA-256 provenance are stored beside this document. No screenshot cropping, programmatic illustration, system icons or replacement permission prompts are used. Existing original navigation artwork remains in use.

## Verification

Static inspection only: PNG headers and asset catalog references resolve; source/copy hashes match; four control/icon images contain alpha; changed labels exist in all five existing localizations; git diff whitespace checks pass. Source comparison confirms that camera permission handling, back/advance, draft loading, photo import and profile save functions remain unchanged. PhotosPicker and actual camera capture remain genuine platform functionality.

No compilation, tests, analyzer, simulator, device run or runtime visual acceptance was performed. The unrelated working-tree project.pbxproj changes were left untouched.
