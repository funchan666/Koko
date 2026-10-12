# Koko app language — 2026-10-11

Implemented in native SwiftUI. Settings → App language offers English, 简体中文,
Español, Français and 日本語. A new/invalid preference defaults to English,
regardless of the device language. The selection is saved under
`koko.interface-language` and restored by `KokoLanguagePreference` on launch.
It is an app/device preference, retained when accounts are changed.

The application injects the selected locale at the root and observes the language
preference. Selecting a language updates localized Text without reconstructing
navigation, restarting the app, signing out, changing stable category values, or
clearing drafts. Language names remain in their native scripts for recoverability.

923 translation keys are bundled in each of five Localizable.strings files.
Shared controls now localize their display strings; native interpolated text
preserves numeric/string arguments. Country search/display follows the interface
locale while the stored region code and canonical profile region remain stable.
User-authored profile names, descriptions, room titles, posts and chat bodies remain
verbatim. Remote legal documents, media, Apple purchase/authorization sheets and
system-owned permission prompts retain their genuine content/platform behavior.

## Resources

- Translation source: [interface-translations.tsv](interface-translations.tsv)
- Regenerate resources: `python3 scripts/generate_interface_localizations.py`
- Original language icon, Garden Host-Native / built-in imagegen:
  [KokoLanguageConversation.png](../../Koko/Resources/KokoArtwork.xcassets/KokoLanguageConversation.imageset/KokoLanguageConversation.png)
- Exact original-artwork prompt: [language-icon-prompt.txt](language-icon-prompt.txt)
- Asset provenance: [language-artwork.json](language-artwork.json)

## Verification boundary

Resource generation verified equal key coverage and matching format arguments in
five languages. All five .strings files passed plist syntax checks. XcodeGen
regenerated the project; the locale variants and new Swift source are present in
the resource/source build phases. Git whitespace checks passed. Source review
confirmed English default, persisted selection, locale propagation, stable route
and category identities, and verbatim content display.

No compilation, automated tests, analyzers, simulator/device launch or visual
runtime acceptance was performed, per the project instructions. On-device language
switching, Dynamic Type and all screen layouts still require runtime acceptance.
