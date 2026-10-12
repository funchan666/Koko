# Conversation studio artwork and integration

Three original Garden / Image 2 host-native outputs, copied unchanged. No crop, recolor or code-drawn replacement. `prompts.json`, `action-prompt.txt` and `provenance.json` record generation inputs and source files.

- `KokoConversationStudioSurface`: quiet ivory folio; the connected conversation forms occupy the lower right. Native copy is inset 24 pt with 50 pt extra bottom clearance.
- `KokoConversationMusicEdition`: mint editorial cover, shown complete using scaledToFit, with real title/content below rather than over the record objects.
- `KokoConversationStudioAction`: deep teal tactile action surface; native localized text centered with accessible touch area.

Navigation: Rooms → Conversation studio; Me → Conversation studio; own voice room → Arrange this conversation. No new tab, invented people, repeated avatars or automatic invitations.

Core files: `SocialDomain/ConversationRunSheet.swift`, `AccountStorage/CommunityConversationStudio.swift`, `Scenes/ConversationStudio/KokoConversationStudio.swift`.

Model fields are optional additions to MemberAccountArchive, preserving old account decoding. Draft text, active step, room binding, private notes, reflection and entitlement persist with the existing atomic protected journal write. The music entitlement has a stable edition ID and no expiry. Repeated unlock requests are idempotent. All core hosting functions remain free.

Static source/resource review only. Images were visually inspected as generated, but no simulator layout acceptance, compilation, payment test or app execution was performed.

## Compact revision

The entrance, studio overview and shared writing/action surfaces now use the [compact revision](compact-revision/README.md). The original 50 pt lower inset and oversized edition image described above are superseded. Music memories retains its complete original cover as a small thumbnail; model, persistence and unlock rules are unchanged.
