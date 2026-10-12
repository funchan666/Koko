# Koko gateway integration · 2026-10-12

## Frozen inputs and deployment

- App ID: `80895233` (string).
- Parent domain supplied by the developer: `dfbbdr.top`.
- API origin: `https://koko.dfbbdr.top`.
- Source of truth: `contract.json`; native constants generated from it. The authentication route suffix was selected once and is now frozen.
- Bundle ID and return scheme: `com.koko.app`. The API domain does not become a WebView permission allowlist.
- Import exactly `generated/接口模板-80895233.json` in interface management and `generated/配置模板-80895233.json` in configuration management; select App 80895233, validate and save.
- Authentication response deliberately retains `#{tokenResult}`. The platform must substitute an actual signed Ably TokenRequest. No API key or fabricated token ships in the app.
- Settlement response is deliberately non-success (`503`). A static JSON response cannot verify a purchase. The settlement handler must validate Apple's receipt, bind the product and transaction to the exact supplied order, perform idempotent settlement, and return HTTP 2xx with integer `code: 0` only after confirmation. Do not change the static response to a success stub.

## Data migration and reproducibility

`source-snapshot/` preserves the exact original source records outside the App target. `export_catalog.py` parses the actual Swift initializers and supplied media manifest, retaining order, IDs, types, descriptions, source file references and model defaults. It also exports generated engagement using the original deterministic formulas and preserves room choreography phrases. It does not modify personal journals.

The exported collection has 6 members, 14 rooms, 54 media records (44 photos and 10 videos), 8 keepsakes, 12 conversation starters, 54 engagement records, 9 existing StoreKit product IDs, 5 topics and 8 room-to-video associations. Room conversations and initial seat maps preserve their original types; `targetAudience` and `tokenCost` match the existing DTO CodingKeys. Sample engagement remains sample content, not a new remote messaging system.

The 54 original media files remain local Bundle resources, including exact filenames and preview references. `ContentLibrary/community-media.json` is a maintenance manifest, no longer bundled or read as an API fallback. UI artwork stays local and unchanged. There were no remote content media URLs in this source export.

At runtime seven public GET routes load concurrently with no body, query or credentials. The coordinator decodes the complete batch, validates IDs, author/host references and bundled media, then replaces one published snapshot. A failed batch preserves the previous complete snapshot and exposes Reload community. An empty initial snapshot is not replaced by bundled mock JSON. Local writes, moderation, wallet, relationships and profiles remain in their existing account journals.

Re-export using:

```sh
python3 docs/BackendAPI/export_catalog.py
python3 /Users/chengdupengyuyan/.codex/skills/prada/scripts/render_contract.py docs/BackendAPI/contract.json --out docs/BackendAPI/generated --replace
cp docs/BackendAPI/generated/IntegrationContract.generated.swift Koko/CommunityGateway/
xcodegen generate
```

## Source-to-entry audit

| Check | Actual path and call chain | Static conclusion / runtime condition |
|---|---|---|
| F01 inputs | contract → generator → IntegrationContract.generated.swift → GatewayClient | API origin, App ID, paths, concrete aliases and event object paths align. |
| F02 data | original snapshots → exporter → responses → both import files → CommunityCollection → existing KokoCommunity/KokoMediaLibrary accessors | Complete source-derived batch; atomic install; local state remains separate. |
| F03 host | project.yml → XcodeGen → Koko target → package products; Info.plist and localized InfoPlist.strings | Ably 1.4.0 and Alamofire 5.12.2 resolved; camera/microphone/photo purpose strings, existing APNs entitlement and bundle return scheme included. Actual SDK public headers inspected. |
| F04 startup | KokoApp / ApplicationDelegate → ArrivalNotifications → publicArrivalFields → authentication / renewal | Registration starts at launch; first active requests notification permission; shared cancellable wait at most five seconds; latest available APNs token used; installation UUID stored and read back in Keychain. |
| F05 entries | ArrivalCoordinator HEAD probe + Alamofire reachability → options GET → SocialWelcome/AccountEntry | Four numeric flags drive actual buttons. Visitor agreement is separate and defaults selected; other entries retain explicit consent. Shared authentication lock; button-area feedback; Apple cancellation releases lock. No authentication journey sleep or new fullscreen skeleton. |
| F06 realtime | tokenConfiguration → ConfiguredRealtimeTransport.start → subscribe before connect → coordinator receive / renewal | One retained client and channel, rewind=1, all-message subscription, single pending renewal, channel/nonce validation and generation cancellation. SDK callbacks use configured main queue; sendable auth callback explicitly hops to MainActor. |
| F07 web | page event → HostedRoomSession.prepare → stable UIViewRepresentable container → current navigation response + didFinish + mounted/active → commit | One WKWebView, 30-second navigation timeout, HTTP 2xx and HTML/XHTML required, error/retry state. Media requests only current trusted main frame with actual AVFoundation authorization. No capture-prevention layer added. |
| F08 routing | ArrivalCoordinator reserve/authenticate/connect/receive/commit | Nonempty data requires signed token even on HTTP 401; empty data only succeeds for HTTP 2xx + numeric code 0. First connected starts one 3-second route wait; no address commits native; malformed address errors; late route cannot replace committed native UI. Saved session restores with public fields only. |
| F09 payment | one KokoAppleCoinPurchases owner → gateway order journal → Apple → purchased persistence → exact five-field receipt confirmation → confirmed persistence → finish | See settlement details below. Updates and unfinished recovery start at App launch, without login dependency. |
| F10 existing functions | RoomBulletins → account notices + durable stage receipts → same real channel | Supports system bulletins only, with ID conflict detection, expiry, capacity limits, persistent received/applied/displayed/read stages and ack-only deletion. Chat, follows and room simulations retain existing local semantics; no RTC or remote presence is asserted. |
| F11 lifecycle | logout/expire → cancel attempt, transport stop, hosted-room close, local session clear → welcome | Installation ID, push coordinator and paid-order ledger survive. Old channel receipts stop; late callbacks cannot reopen login. Payment UI detaches without discarding transactions. |

## Payment ownership and recovery

The app retains a single StoreKit 2 updates observer. Native coin-pack purchases keep the existing account-token credit/revocation journal. Their three finish branches still require the existing durable native accounting result; the gateway never grants native coins for a hosted order.

Hosted orders bind the backend order string, event ID, Apple product, local owner, existing account appAccountToken, independent local order UUID, original API origin/path, concrete confirmation field names, installation ID and edition before Apple purchase. Account tokens retain their account-binding meaning. The direct verified purchase callback associates its transaction ID with that exact local order before confirmation. Legacy order-specific tokens remain readable, but no new order repurposes the account token. The five-string payload uses the raw app receipt in Base64, not StoreKit's JWS; receipt bytes are never logged or persisted. An absent receipt can trigger one real receipt refresh during an explicit foreground purchase, never during startup recovery.

If the process dies after Apple payment but before the transaction/order association is written, an account token and product alone cannot establish the backend order. Such transactions are quarantined unfinished for reconciliation, never assigned to the latest same-product order or credited to the native wallet. New purchases of the same product/account are blocked while that association is unresolved. The supplied backend contract has no reconciliation lookup endpoint; those ambiguous cases require operator reconciliation. Once an association is durable, recovery automatically submits that original order. Persisted event IDs also prevent the same cancelled or failed delivery from opening Apple purchase again; an explicit new attempt needs a new event ID.

Only HTTP 2xx + integer `code: 0` advances the hosted order to durable `confirmed`; only then is `transaction.finish()` called, followed by durable `finished`. Crash between these steps is replay-safe. Failures retain pending records; the bounded retry schedule is immediate, 2 and 5 seconds, followed by a future launch/network/foreground recovery. Existing purchased ledger rows also retry confirmation if Apple has not replayed them yet. Confirmed records finish when Apple replays the transaction. Unknown transactions are quarantined rather than assigned to the latest user or order. Corrupt ledgers are not overwritten.

Explicit purchases synchronously lock and show an interaction-blocking text-only overlay before product lookup. The overlay remains through confirmation/finish, or until a clear failure, cancellation, Apple pending result, or bounded retry exhaustion. Forced logout detaches that UI but preserves submitted/paid work. Dynamic backend products are fetched only on an authenticated purchase event; native packs are fetched only on their Buy action.

## Extended bulletin protocol

`bulletin-protocol.json` is documentation of additional runtime capabilities, not an extra console import. Four standard event slots remain exactly four. Backends wishing to send system notices must implement bulletin delivery, receipt acknowledgments and replay. A publish completion is never treated as business acknowledgment. Rewind=1 is not offline history. Notice read stages follow actual user changes in the existing inbox; displaying a notice does not mark it read.

## Verification boundary and operational prerequisites

The supplied October 12 device log confirms authentication HTTP 200, an Ably connection and receipt of the page event. It does not include navigation-delegate milestones, so it does not establish why the page timed out. The hosted WebView now stays at normal opacity behind the welcome view and starts loading only after its container has a window and nonzero layout. The same instance is revealed after validated navigation completion. Mounting and document loading have separate bounded waits; failure stops loading, and retry resets its caption. Debug navigation logs report HTTP/MIME, completion and timeout phase without signed URL parameters. These changes have only been statically inspected.

This round performed source/configuration/resource-reference inspection, source-derived JSON export/comparison, plist validation, dependency resolution and Git whitespace checks. It did **not** compile, run tests/analyzers, launch the app/simulator, call Koko business APIs, connect Ably or initiate a purchase. Generated Xcode project and resolved packages are not build evidence.

Still requires deployment and explicit later integration verification: actual signed-token substitution/renewal, route messages and hosted HTML behavior, real settlement verification/idempotency, bulletin ack/replay, APNs delivery on signed devices, App Store Connect consumables and signing credentials. The existing local profile deletion is not a server-account deletion endpoint; no such API was supplied. Existing local private chat/media checks are not converted into RTC. Operator-hosted policies must describe the deployed backend's actual authentication/content/payment processing. No claim of App Review approval or review-evasion behavior is made.

SDK references inspected: https://github.com/ably/ably-cocoa/tree/1.4.0 and https://github.com/Alamofire/Alamofire/tree/5.12.2 .

UI routing: evaluated Taste (web frontend scope), Design (existing design-system context) and Garden (original raster workflow). This integration keeps native SwiftUI and reuses existing Koko original entry/control/dialog artwork; no new raster art, web prototype or unrelated visual redesign was needed.
