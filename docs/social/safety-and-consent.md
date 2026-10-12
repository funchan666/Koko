# Koko consent, safety and publishing — 2026-10-12

## Implemented locally

- Names and portraits link to the member profile in conversations, message authors,
  comments, room seats/rosters, discovery cards, host rows, connection lists and calls.
  Profile chat actions open the conversation even before mutual consent. Sending
  and call preparation independently enforce mutual following and visibility.
- Outgoing follow/unfollow choices persist per account. Incoming consent must come
  from an independently confirmed source; the client never creates it. Legacy
  automatic sample followers, sample friendship actions and incoming sample chat
  entries are removed once. User-authored messages and outgoing follows remain.
- Conversation drafts, attachments and messages persist in the account journal.
  Writes use atomic replacement; observable state changes only after a successful
  save. No simulated replies or delivered statuses are generated.
- Shared report reasons apply to profiles, posts, comments, room messages and
  conversations, including individual private messages. Saving a report atomically
  stores the reason and hides the reported identifier. Blocking hides the author,
  their posts, comments, hosted rooms, room entries and private conversations.
- Blacklist contains only persisted blocked IDs. Unblocking does not restore
  follows, mutual consent or independently reported content.
- New posts are stored in a private pending queue, available through My submissions.
  They cannot enter the public collection through a timer or client approval toggle.
  Submissions can be withdrawn. Live-preview media is excluded from attachments.
- Report/block/unblock and post-review receipts use two newly generated original
  artworks. Prompts and exact-file provenance are in design/safety-and-publishing.
- Native AVFoundation remains the camera implementation. Call preparation requests
  microphone permission and video preparation requests camera permission; the
  preview is genuinely local. Leaving, interruption, backgrounding or losing
  eligibility releases capture. There is no Flutter camera plugin in this project.
- Settings and login share KokoLegalWebPage and KokoLegalDocument for terms/privacy.
  Community guidelines cover conduct, consent, minors, privacy, reporting, blocking
  and the limits of this local build. No Contact us button was added.
- Sign out clears the persisted active session, then shows a success receipt and
  opens Log in. Delete removes the local account journal, credentials and portrait,
  then shows success and opens Welcome. Failure never produces a success receipt.

## Service boundary

There is no supplied relationship/messaging/moderation service. Accordingly, no
incoming follow consent, message delivery, remote call, report submission to a team,
review approval or public publication is fabricated. `confirmedFollowerIDs` is
empty for new accounts and must eventually be populated by verified relationship
responses. With no verified mutual relationship, send/call actions remain locked.
The supplied profiles and media remain a clearly local content preview, not real
friends or online people. Account deletion here deletes device-local account data;
remote account deletion and Apple token revocation require service integration.

Apple guideline 1.2 requires filtering, reporting with timely responses, blocking
and published contact information. Mutual following is Koko's product policy and
is not a substitute for those operational obligations. Local reports and this
private review queue alone do not establish App Review compliance. A production
launch needs moderation and verified support details (not invented placeholders).
Source: https://developer.apple.com/app-store/review/guidelines/#user-generated-content

## Verification boundary

Inspected source paths, relationship guards, journal migration, visibility filters,
account departure handling and native capture lifecycle. Regenerated the project
with XcodeGen; verified new sources are in its source phase. Plist syntax checks
passed for Info.plist, project.pbxproj and all five localization resources. Verified
both generated artwork files match their asset catalog copies exactly.

No build, tests, analyzer, simulator/device run or runtime visual acceptance was
performed, as required by the project instructions. Rendering, transitions,
permission prompts and relaunch behavior still need runtime acceptance when asked.
