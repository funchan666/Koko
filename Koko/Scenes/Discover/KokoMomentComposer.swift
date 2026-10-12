import SwiftUI

struct KokoMomentComposer: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @State private var caption = ""
    @State private var topic = "Conversation"
    @State private var mediaID: String?
    var body: some View {
        KokoPage(title: "A moment to share", subtitle: "Make room for your story", back: navigation.back) {
            KokoField(label: "Your words · up to 1000 characters", value: $caption, multiline: true)
            KokoChoiceRail(choices: KokoCommunity.topics.filter { $0 != "All" }, selection: $topic)
            Text("Choose a photo or video").font(KokoTypography.heading(size: 20))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(KokoMediaLibrary.assets.filter { !KokoMediaLibrary.liveRoomPreviewAssetIDs.contains($0.id) }) { asset in
                        Button { mediaID = asset.id } label: {
                            VStack {
                                KokoContentImage(asset: asset).frame(width: 110, height: 132).clipped()
                                Text(LocalizedStringKey(mediaID == asset.id ? "Selected" : (asset.isVideo ? "Video" : "Photo")))
                                    .font(KokoTypography.medium(size: 12))
                            }
                        }.buttonStyle(KokoPressStyle()).accessibilityAddTraits(mediaID == asset.id ? .isSelected : [])
                    }
                }
            }
            if mediaID != nil { KokoAction(title: "Remove attachment", emphasis: false) { mediaID = nil } }
            Text("Posts stay private until review approval. This build stores submissions on this device; the review service is not connected.")
                .font(KokoTypography.body(size: 14)).foregroundStyle(KokoInk.secondary)
            KokoAction(title: "Submit for review") {
                if community.submitMoment(caption: caption, topic: topic, mediaAssetID: mediaID) {
                    navigation.back()
                }
            }
        }
    }
}

struct KokoPendingMomentsView: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    var body: some View {
        KokoPage(title: "My submissions", back: navigation.back) {
            let submissions = community.journal?.pendingMoments ?? []
            if submissions.isEmpty { KokoEmpty(title: "No submissions yet", detail: "Your posts awaiting review will appear here, visible only to you.") }
            ForEach(submissions) { submission in
                KokoCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Awaiting review service").font(KokoTypography.emphasis(size: 12)).foregroundStyle(KokoInk.accent)
                        Text(verbatim: submission.caption).font(KokoTypography.medium(size: 17))
                        if let asset = KokoMediaLibrary.asset(submission.mediaAssetID) {
                            KokoContentImage(asset: asset).frame(height: 180).clipped()
                        }
                        Text(submission.submittedAt, style: .date)
                        KokoAction(title: "Withdraw submission", emphasis: false) {
                            if community.update({ $0.pendingMoments?.removeAll { $0.id == submission.id } }) {
                                community.feedback = .init(title: "Submission withdrawn", message: "This post was removed from your private review queue.")
                            }
                        }
                    }
                }
            }
            KokoAction(title: "Create a post") { navigation.open(.composeMoment) }
        }
    }
}

struct KokoProfileLink<Content: View>: View {
    @EnvironmentObject private var navigation: KokoSceneNavigation
    let memberID: String
    @ViewBuilder var content: Content
    var body: some View {
        Button { navigation.open(.profile(memberID)) } label: { content }
            .buttonStyle(KokoPressStyle()).accessibilityHint("Opens this person's profile")
    }
}
