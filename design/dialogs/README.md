# Koko dialog artwork refresh

## Design and delivery

Native SwiftUI remains the implementation. Garden / GPT Image 2 Host-Native plus the built-in image generator produced eight independent original PNG assets. Taste, Claude Design and browser Garden skills were evaluated and not forced into this native iOS task. Prompts are beside this document; original images are in `assets/original-ui/dialogs/`; source paths and hashes are in `source-files.json`. Entire generated images are copied unchanged into the asset catalog, with no screenshot crops, code-drawn illustrations or default system icon replacements.

Deep petrol glass with porcelain and mint lettering replaces the older green panels. Compact menus avoid oversized decoration; mutual-follow, safety, completion and pending-review dialogs have dedicated illustrations. The review hourglass is distinct from the completed-action checkmark. Body text and all action labels remain native and localized.

## Coverage

All app-owned popup families now use KokoModal: ordinary choices/confirmations, notices/purchase results, action feedback/publishing review, policy consent reminders, and the previously separate country picker. Scoped artwork also reaches buttons, fields, menu rows, report-reason rows, nested cards, gift selections and Conversation Studio actions inside dialogs. Ordinary page controls retain their appearance.

Account changes, deletion, reporting/blocking, room controls/audience/gifts, filters, photo attachments, album selections, keepsakes, conversation plans, answer editing and mutual-follow gates are included. Genuine PhotosPicker, camera capture pages, legal web reading, Apple authorization, purchases and OS permission prompts keep their actual platform flows. Full-screen brand loading remains the requested brand presentation.

## Layout and interaction

Short panels use intrinsic content height; longer lists/body copy scroll below a persistent title/close action. The width is bounded on iPad, and safe-area/keyboard proposals stay respected. Native Dynamic Type, 44-point close targets, modal VoiceOver focus/escape and Reduce Motion are supported in source. Original functional closures, persistence, mutual-follow gating and permission requests remain unchanged. Feedback/purchase notices require an explicit action rather than an accidental backdrop tap.

## Verification

Static only: all eight PNGs retain alpha, copies match source SHA-256 values, all new asset references resolve, legacy popup backgrounds are no longer referenced, existing labels remain localized, and git diff whitespace checks pass. No compile, tests, analyzer, simulator, device run or runtime visual acceptance was performed.

## Source inventory

30 dialog call sites (dynamic room/confirmation dispatches cover multiple scenarios).

| Source | Declaration |
| --- | --- |
| `Koko/Scenes/Discover/KokoConversationStarters.swift:137` | `KokoModal(title: "Who is this question for?", presentation: .selection,` |
| `Koko/Scenes/Discover/KokoConversationStarters.swift:325` | `KokoModal(title: "Your answer",` |
| `Koko/Scenes/Discover/KokoDiscoverView.swift:93` | `KokoModal(title: "Room topics", presentation: .selection,` |
| `Koko/Scenes/Discover/KokoDiscoverView.swift:572` | `KokoModal(title: "Collection filters", presentation: .selection,` |
| `Koko/Scenes/Discover/KokoDiscoverView.swift:710` | `KokoModal(title: "Make it your kind", presentation: .selection,` |
| `Koko/Scenes/Discover/KokoDiscoverView.swift:748` | `KokoModal(title: confirmBlock ? "Block this person?" : "Keep your space comfortable", presentation: .safety,` |
| `Koko/Scenes/Discover/KokoMomentDetail.swift:189` | `KokoModal(title: confirmingBlock ? "Block this person?" : "More", presentation: confirmingBlock ? .safety : .compact,` |
| `Koko/Scenes/ConversationStudio/KokoConversationStudio.swift:114` | `KokoModal(title: "Unlock Music memories?",` |
| `Koko/Scenes/ConversationStudio/KokoConversationStudio.swift:198` | `KokoModal(title: confirmation == "delete" ? "Delete this plan?" : "Keep a reflection?", presentation: confirmation == "delete" ? .safety : .connection,` |
| `Koko/Scenes/ListeningRooms/KokoListeningRoomView.swift:221` | `KokoModal(title: title, presentation: .selection,` |
| `Koko/Scenes/Conversations/KokoConversationsView.swift:60` | `KokoModal(title: "Clear your conversations?", presentation: .safety,` |
| `Koko/Scenes/Conversations/KokoConversationsView.swift:269` | `KokoModal(title: "Choose a photo", presentation: .selection,` |
| `Koko/Scenes/Conversations/KokoConversationsView.swift:275` | `KokoModal(title: "Attached photo", presentation: .selection,` |
| `Koko/Scenes/Conversations/KokoConversationsView.swift:282` | `KokoModal(title: "Clear this chat?", presentation: .safety,` |
| `Koko/Scenes/Conversations/KokoPrivateCallView.swift:85` | `KokoModal(title: "A hello goes both ways.", presentation: .connection,` |
| `Koko/Scenes/Account/KokoProfileEditor.swift:90` | `KokoModal(title: "Camera unavailable",` |
| `Koko/Scenes/Account/KokoProfileEditor.swift:232` | `KokoModal(title: "Country or region", presentation: .selection,` |
| `Koko/Scenes/PersonalSpace/KokoCoinCelebration.swift:9` | `KokoModal(title: "A little gesture, on purpose",` |
| `Koko/Scenes/PersonalSpace/KokoPersonalSpace.swift:50` | `KokoModal(title: "Until next time?", presentation: .connection,` |
| `Koko/Scenes/PersonalSpace/KokoPersonalSpace.swift:471` | `KokoModal(title: confirmsBlock ? "Block this person?" : "More", presentation: confirmsBlock ? .safety : .compact,` |
| `Koko/Scenes/PersonalSpace/KokoPersonalSpace.swift:580` | `KokoModal(title: "Choose a photograph", presentation: .selection,` |
| `Koko/Scenes/PersonalSpace/KokoPersonalSpace.swift:593` | `KokoModal(title: "Your album", presentation: .selection,` |
| `Koko/Scenes/PersonalSpace/KokoPersonalSpace.swift:605` | `KokoModal(title: "Saved illustration", presentation: .selection,` |
| `Koko/Scenes/PersonalSpace/KokoSettingsAndSafety.swift:55` | `KokoModal(title: confirmation.title, presentation: .safety,` |
| `Koko/Scenes/PersonalSpace/KokoSettingsAndSafety.swift:158` | `if clearingMessages { KokoModal(title: "Clear conversations?", presentation: .safety,` |
| `Koko/Scenes/PersonalSpace/KokoSettingsAndSafety.swift:219` | `if let memberID = selectedID { KokoModal(title: "Unblock this person?", presentation: .safety,` |
| `Koko/Scenes/PersonalSpace/KokoWalletAndKeepsakes.swift:32` | `KokoModal(title: keepsake.keepsakeName,` |
| `Koko/AccountAccess/KokoLegalWebReader.swift:170` | `KokoModal(title: "One quick step.", presentation: .safety,` |
| `Koko/InterfaceArtwork/KokoNoticePanel.swift:10` | `KokoModal(title: heading, dismissOnBackdrop: false,` |
| `Koko/InterfaceArtwork/KokoNoticePanel.swift:24` | `KokoModal(title: feedback.title,` |
