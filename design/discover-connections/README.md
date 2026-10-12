# Discover: moments and first connections

Scope: the highlighted lower section below the featured moment grid. The live directory, existing moment cards and tab bar are unchanged by this revision.

- One feed invitation replaces the duplicate thumbnail collage and opens the existing moments collection.
- Host invitation cards show one supplied portrait, full name, interest and original introduction. Profile, persisted follow toggle and conversation actions are separate buttons. Existing mutual-connection requirements remain enforced inside chat; this UI does not invent online presence or message delivery.
- The two bottom entries now open people search and voice-room creation. The redundant second media-collection entry is removed.
- Native copy uses the five bundled languages. Accessibility text sizes stack the feed and bottom actions; the host rail becomes a vertical list. Portraits, names and introductions retain their original content.

Art direction: cream invitation paper, mint action accents, dark green copy and three semantic tactile objects. No decorative portraits, title icons, system icons, double outlines or programmatically drawn decorative artwork were added.

Four new raster assets were generated with the built-in image tool through Garden Host-Native, visually inspected, and copied into the asset catalog without cropping or pixel edits. [assets.json](assets.json) records the final paths, prompts and original output paths. The existing original `KokoCollectionMintSurface` is reused for neutral mint surfaces.

Validation: source and route inspection, five-language string-format checks, catalog JSON/resource-reference checks, original/source SHA256 comparison and `git diff --check`. No build, test, analyzer, simulator or device run; the assembled native screen is not runtime-verified.
