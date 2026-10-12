# Koko room-card artwork

Workflow: Garden GPT Image 2, Host-Native image generation. All three assets were generated from scratch, copied into the asset catalog without cropping or image post-processing. SwiftUI owns content, sizing, accessibility and interactions.

## Room card

Asset: `Koko/Resources/KokoArtwork.xcassets/KokoRoomEditorialCard.imageset/KokoRoomEditorialCard.png`

Prompt:

Create a brand new original production raster UI asset for Koko social app. ONE portrait card shell, 2:3 aspect ratio, complete smooth rounded corners, face-on flat orthographic UI artwork, transparent only outside the rounded corners. Card fills the entire image bounds edge to edge: no outer margins. Upper 55 percent is a calm solid deep petrol #103A36 empty area where the app will overlay a video photograph. Lower 45 percent warm pale ivory #F0EBDD completely clear writing space for native dark text. Seam between these areas perfectly horizontal. Design aesthetic contemporary independent social magazine, friendly and tactile, subtle fine paper grain, restrained original art direction. Very small abstract coral conversation-thread flourish confined to bottom right corner in bottom 3 percent only. NO text, NO icons, NO people, NO photos, NO inset panels, NO frames, NO outlines, NO double borders, NO bevels, NO glow, NO glass bubbles, NO cut corners, NO 3D object, NO drop shadow. This is the actual usable card material, not a mockup or a picture of a card. Entire card front fills image.

## Video-room status

Asset: `Koko/Resources/KokoArtwork.xcassets/KokoVideoRoomStatus.imageset/KokoVideoRoomStatus.png`

Prompt:

Original Koko social room status UI badge production asset. Single small horizontal coral enamel speech lozenge, 3:1 aspect ratio, fill bounds nearly edge to edge with only tiny transparent corner space. Soft smooth round ends and subtle small chat tail bottom left. Left quarter contains original dark petrol tiny video camera glyph, friendly sculpted silhouette, no stock icon. Right three quarters totally empty solid coral for native text. Flat front-on design, refined slight material texture, clear small-size readability. NO words, NO text, NO outline, NO glow, NO double borders, NO shadow, NO people, NO decorative image, NO perspective. Single clean functional button meaning video-room preview. Transparent background outside object.

## Conversation surface

Asset: `Koko/Resources/KokoArtwork.xcassets/KokoConversationPaper.imageset/KokoConversationPaper.png`

Prompt:

Create one original production raster UI card surface for Koko social app, aspect 3:2 landscape. Fill canvas edge to edge, transparency only at complete smoothly rounded outer corners. Flat front-on matte dusty teal #214943 with barely visible paper grain, no borders or frames, no bevels, no neon, no glow. Tiny handpainted coral and warm ivory threads softly intertwine solely in the bottom-right 8 percent, like two conversations meeting, without speech bubble icons or people. Other 92 percent quiet uniform empty space for native profile/chat text. Crisp sophisticated editorial social app style, understated warm personality, not a game panel. No text, no icons, no photos, no people, no inset objects, no perforations, no cut corners, no shadows, no outside margins. This is a reusable actual card surface artwork not a presentation mockup.

## Integration

- Live, voice and moment cards share an explicitly bounded layout. All directory cards have the same height, media fraction and text reservations.
- Video-room cover uses its existing first-frame resource. Voice-room cover uses its host's supplied photo.
- Room media and community-video selection remain separate.
- The status badge says PREVIEW because these rooms do not have a remote live transport.
- Personal-space top title removed. Existing navigation actions and wallet balance are preserved.

Verification: source, resource references and diff reviewed only. No compilation, tests, analyzer or simulator/device run performed. Runtime appearance remains unverified.
