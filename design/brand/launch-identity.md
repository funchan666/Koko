# Koko launch identity

The user supplied lg.png replaces the previous brand artwork. AppIcon and KokoBrandMark share its original 1024 by 1024 RGB pixels. The source alpha was fully opaque and is omitted from the distribution PNG for App Icon compatibility. No crop, repaint, recolor or lossy encoding was applied.

Both launch surfaces use an opaque deep violet backdrop, sRGB #140B24. The 160 point brand image is centered on the window. A 28 point loading light is placed 24 points below it, with no visible caption. Account transition captions remain available to VoiceOver.

KokoLoadingLight was created with the built-in Image 2 workflow. Its prompt is loading-light-prompt.txt. The static launch storyboard displays the same image in its initial position; the native waiting screen rotates the whole raster every 1.4 seconds. Reduce Motion and inactive scenes show it still. System launch screens cannot run the application animation.

Taste and browser engineering were evaluated and were not applicable to this native change. Design guided the supplied-asset hierarchy and spacing; Garden guided the original loading accessory. SwiftUI and the system launch storyboard remain the implementation.

Validation is static: image pixel equivalence, alpha, source references, catalog entries, launch XML, project configuration and diff inspection. No compilation, simulator, device run or runtime visual acceptance.

Supplied source SHA256: 3691f24d4df57413ec4e774f6b95c813500a983693e11665eb42d4a6df5e5413
