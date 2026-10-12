# Koko — more ways to connect

## Delivered scope

- **Conversation starters:** 12 original questions across Conversation, Music, Creative and After hours. Browse topics, move to the next card, save/unsave and filter saved questions. Open from Discover, the voice directory or a private conversation.
- **Common ground:** filter people by topic and shared interests, sort by the actual intersection of profile interests, view profiles, follow and choose a question for that person. No invented compatibility percentages or presence claims. Existing blocked/hidden-member filters remain in force.
- **Personal answer cards:** choose a question, write a 1–240 character answer, save, edit, confirm removal and preview the profile. Saved answers render on the profile. Unsaved edits require an explicit discard action when dismissing the editor.

## Connected behavior

A question appends to the recipient's existing draft and opens the chat for review. It does not send a message. Text and photo drafts survive the detour. Only mutual friends may receive a prepared draft; other profiles retain the existing mutual-connection flow. Full drafts and persistence failures do not navigate as if saving succeeded.

The voice-room action fills the existing composer with a localized room name, question and stable topic identifier. The user edits and explicitly creates the room through the existing flow. Opening the composer does not start microphone capture.

Favorites, answers and photo drafts are optional Codable fields, so older account journals remain readable. All saves use the existing atomic, account-specific journal store. They are device-persisted features; this change does not add remote messaging, matching, profile publication or RTC infrastructure.

## Original visual work

Skill routing: Design guides native hierarchy; Garden `gpt-image-2` + `imagegen` use Host-Native generation. Taste's frontend implementation and Garden's web deliverables are outside this SwiftUI task's scope.

The three complementary treatments are an apricot question sheet, cream people invitations and an open writing journal. Discover uses one question invitation with a lighter unboxed common-interest link below it. Functional objects have meaning: a conversation deck, linked speech bubbles and a writing journal. No people illustrations were added to headings.

Typography stays in the existing Avenir Next family: 24–28 pt questions, 18–21 pt headings, 12–16 pt supporting copy. Native text scales with Dynamic Type; action arrangements can stack and pages/modal editors scroll. Hit areas are at least 44 pt. UI uses the original raster surfaces without drawing replacement artwork in code.

Four images were generated with the built-in image tool, reviewed visually and copied unchanged into `Koko/Resources/KokoArtwork.xcassets/`. No cropping, repainting, slicing or alpha manipulation was applied. [assets.json](assets.json) records exact source/output paths, prompt paths and SHA256 hashes. The four adjacent `.txt` files are the exact generation prompts.

## Source map

- `Koko/SocialDomain/ConversationStarters.swift`: question catalog, guarded writes, shared-interest calculation.
- `Koko/Scenes/Discover/KokoConversationStarters.swift`: three screens, Discover invitation and personal-answer presentation.
- `Koko/Application/KokoSceneNavigation.swift`: destinations.
- `Koko/Scenes/ListeningRooms/KokoRoomDirectory.swift`: prefilled composer.
- `Koko/Scenes/Conversations/KokoConversationsView.swift`: conversation entry and text/photo draft preservation.
- `Koko/Scenes/PersonalSpace/KokoPersonalSpace.swift`: personal entry and profile answers.
- `design/localization/interface-translations.tsv`: reviewed English, Chinese, Spanish, French and Japanese copy; 858 total keys per bundled language after generation.

## Validation boundary

Completed source/configuration/resource inspection: all new destinations have consumers and entry points; optional journal fields preserve old-account decoding; all new literal UI strings are in the five-language table; four asset references resolve and image bytes match their original generation outputs. Generated the Xcode project from the existing `project.yml` source glob to register the two new Swift files. `plutil -lint` for project and strings and `git diff --check` are clean.

Per project instructions, no compilation, test execution, analyzer, simulator or device run was performed. Artwork itself was visually reviewed; the assembled native screens and runtime persistence/navigation still need device acceptance.

When runtime acceptance is requested, exercise: old account restore; independent accounts' saved questions and answers; save/unsave of the last filtered card; long translations and accessibility text sizes; mutual/non-mutual/blocked recipients; text-plus-photo draft detour; full draft rejection; answer save/edit/discard/delete; profile preview; and explicit creation from a prefilled voice-room composer.
