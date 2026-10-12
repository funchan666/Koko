# Compact Conversation studio revision

## Design and skill routing

Native SwiftUI remains the implementation. Taste and Design were evaluated against their web/artifact scopes; no HTML deliverable or prototype is needed for this focused native revision. Garden `gpt-image-2` Host-Native and `imagegen` supplied three original raster skins. Prompts are in [prompts.json](prompts.json); unchanged original output paths and SHA-256 hashes are in [provenance.json](provenance.json).

- `KokoStudioInvitationStrip`: one compact, whole-row entrance with integrated conversation slips and a directional mark. Native copy sits between them. Nominal height 88 pt, expanding for longer localized text; width capped at 380 pt to retain artwork/text clearance.
- `KokoStudioNoteSurface`: quieter ivory writing paper replaces the oversized illustrated folio in empty states, saved plans, question editing and private notes. Insets are 20 pt plus 8 pt lower clearance, replacing the previous 24 + 50 pt treatment.
- `KokoStudioCoralAction`: a restrained coral action surface, 48 pt minimum hit height. Replaces the skinny teal pill in the studio and plan flows.

The image generator exported transparent margins. Native background layout expands the COMPLETE PNG vertically to align its opaque surface with the content/hit area. No crops, masks, recoloring, synthesized shapes, or pixel edits are used. The original images are copied byte-for-byte into `assets/original-ui/conversation-studio/` and the asset catalog. Transparent overflow is decorative and cannot intercept touches.

## Information hierarchy

The directory and personal-space entrance now use a single compact row. The studio opens with a short explanation and free create action, followed immediately by saved plans (or a short empty state). The Music memories artwork is shown complete at 86 pt wide, beside its title. All six questions are available through an explicit expand/collapse control before the existing 80-coin confirmation. Ownership, account-bound persistence, free planning, private notes, hosting cues and reflection actions remain unchanged. Local-storage and no-invitation disclosures remain visible. Ten new strings are included in all five bundled languages.

## Verification boundary

Source, asset references, unchanged image hashes, localization resources and Git whitespace were checked. XcodeGen regenerated the project from `project.yml`. No compilation, tests, analyzer, simulator or device run was performed. Final runtime layout and Dynamic Type acceptance remain unverified.
