# Voice room invitations — 2026-10-10

## Direction
Original Garden / Image 2 host-native raster assets. Voice directory uses a single column of equal-height invitations: host portrait on the left, pale sage information area on the right. No repeated avatar, photo-covering label, fake audience count, system icon, cut corner, double outline, or title illustration. Six topic choices remain visible in two rows. Native text, accessibility and navigation stay in SwiftUI.

## Original assets
All three images were newly generated, copied intact into KokoArtwork.xcassets, and retained at their original source paths. No old UI crop, code drawing, image compositing or postprocessing.

Source: original artwork generation archive.

- `KokoVoiceInvitationCard`: `exec-e787d579-8447-48eb-85b7-26ccb48d1ae8.png`. Landscape 2:1 card, deep petrol portrait area on the left, pale blue-sage text area on the right, restrained sound-wave/conversation detail at the bottom. Smooth complete rounded corners.
- `KokoVoiceTopicSelection`: `exec-04b6f66f-0953-4522-9a6f-e7cb33d7b3d3.png`. Pale pistachio selected-topic skin with blank native-text area and small coral baseline stitch, no outline.
- `KokoStartVoiceRoom`: `exec-56ea78ad-891b-4399-ad4c-f1d4a67fbbad.png`. Original coral microphone-plus action tile.

## Layout and behavior
- Room cards have a shared 210pt base height, scaling with the body text setting.
- Explicit 42.6% portrait area matches the artwork seam. Full card clipping preserves rounded outer corners; actual supplied photographs remain the covers.
- Topic, title, host name and room action each appear once. Content uses dark text over the light artwork.
- Category selection preserves topic and following filters. Search still matches room title, topic and host.
- Create, ranking and room navigation are preserved; room composer is unchanged.
- Previews remain labeled as previews. No fabricated online counts.

## Validation boundary
Source, asset references, JSON and git diff inspection only. No compilation, tests, analyzer, simulator or device execution.
