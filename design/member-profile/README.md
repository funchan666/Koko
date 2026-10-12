# Koko member profile — photo first

The member detail page now uses one large cover photo with the name and demographic details underneath. The inset avatar, code-drawn image outline, dark image gradient and separate boxed statistics were removed. The profile's room entries no longer repeat the host portrait, and the profile's moments exclude its supplied portrait photo (that content remains available elsewhere).

A new original ivory paper surface groups the biography and interests. The hierarchy is name (30 pt), biography (20 pt), interests (15 pt) and supporting copy (12–13 pt), using Koko's Avenir Next family and native Dynamic Type. Counts appear as compact text, not another card. No empty demographic separators or age 0 appear for unfinished profiles.

The primary mint hello button and quieter petrol controls use newly generated bitmap surfaces. Follow, chat, voice, video, icebreaker selection, report/block and the explicitly labeled sample-connection flow retain their existing destinations and authorization checks. Moments and rooms use a content selector; actual content remains reachable. Saved question answers remain visible.

Skill routing: Design for native hierarchy and Garden / Image 2 Host-Native for original raster assets. Taste/frontend and HTML artifact workflows are outside this native SwiftUI scope. Three original standalone assets were generated with the built-in image tool, visually inspected and copied into the asset catalog without cropping, recoloring, slicing or alpha editing. Native clipping is used only for the content photograph.

Exact prompts are in the adjacent three `.txt` files. [assets.json](assets.json) records source images, in-project outputs and SHA256 hashes. Implementation is in `Koko/Scenes/PersonalSpace/KokoPersonalSpace.swift`; existing shared components outside this profile are unchanged.

Static inspection confirms one `KokoMemberCoverPhoto` and no `KokoMemberPortrait` in the profile implementation, all three image references resolve, all new copy is localized in five languages, localization property lists parse, and the Git diff has no whitespace errors. Asset bytes match their generation outputs. Existing modal content is hidden from accessibility and hit testing while a safety or sample confirmation is open.

No build, tests, analyzer, simulator or device execution was performed. Assembled native layout and interaction are not runtime-verified. When device acceptance is requested, check long names, largest accessibility text, long translations, own-profile vs another member, blocked profiles, both content tabs, and the existing chat/call gates.
