import Foundation

struct KokoSafetyTarget {
    var contentID: String
    var memberID: String
}

struct KokoActionFeedback: Identifiable {
    var id = UUID()
    var title: String
    var message: String
    var awaitingReview = false
}

enum KokoSafetyReason {
    static let all = ["Harassment", "Hateful content", "Sexual content", "Violence", "Spam or scam", "Privacy concern", "Child safety", "Other"]
}

struct PendingCommunityMoment: Identifiable, Codable {
    var id = UUID().uuidString
    var authorID: String
    var caption: String
    var topic: String
    var mediaAssetID: String?
    var submittedAt = Date()
    var reviewState = "awaiting-service"
}

@MainActor
extension CommunityJournalStore {
    func isContentHidden(_ id: String) -> Bool { journal?.hiddenContentKeys.contains(id) == true }
    func isMemberVisible(_ id: String) -> Bool {
        member(id) != nil && journal?.blockedMembers.contains(id) != true && !isContentHidden(id)
    }
    func isEntryVisible(_ entry: ConversationEntry) -> Bool {
        isMemberVisible(entry.authorMemberID) && !isContentHidden(entry.id)
    }
    func comments(for momentID: String) -> [ConversationEntry] {
        (KokoMomentConversationSeeds.comments(for: momentID) + (journal?.momentComments[momentID] ?? [])).filter(isEntryVisible)
    }
    func momentLikeCount(_ momentID: String) -> Int {
        KokoMomentConversationSeeds.likeCount(for: momentID) + (journal?.likedMomentKeys.contains(momentID) == true ? 1 : 0)
    }
    func toggleMomentLike(_ momentID: String) {
        guard moments.contains(where: { $0.id == momentID }) else { return }
        update {
            if $0.likedMomentKeys.contains(momentID) { $0.likedMomentKeys.remove(momentID) }
            else { $0.likedMomentKeys.insert(momentID) }
        }
    }
    @discardableResult
    func requireMutualConnection(_ memberID: String) -> Bool {
        guard journal != nil, accountDeparture == nil, memberID != myID,
              isMemberVisible(memberID), !isContentHidden("conversation-" + memberID), friends.contains(memberID) else {
            notice = "You both need to follow each other before sending messages or starting a call. Following someone never accepts on their behalf."
            return false
        }
        return true
    }
    func removeSimulatedRelationships(_ value: inout MemberAccountArchive) -> Bool {
        guard value.removedSimulatedRelationships != true else { return false }
        value.sampleFollowers = []
        value.sampleFollowerArrivals = []
        value.notices.removeAll { $0.sampleFollowerID != nil || $0.headline == "Sample friendship added" }
        let sampleIDs = Set(KokoCommunity.members.map(\.id))
        for index in value.privateConversations.indices {
            value.privateConversations[index].entries.removeAll { sampleIDs.contains($0.authorMemberID) }
        }
        value.privateConversations.removeAll { $0.entries.isEmpty && $0.compositionDraft.isEmpty && $0.compositionPhotoDraft == nil }
        value.removedSimulatedRelationships = true
        return true
    }
    @discardableResult
    func submitMoment(caption: String, topic: String, mediaAssetID: String?) -> Bool {
        let text = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hasCurrentPolicyConsent, hasCompletedAccountEntry, accountDeparture == nil,
              !text.isEmpty, text.count <= 1000,
              KokoCommunity.topics.contains(topic), topic != "All",
              mediaAssetID == nil || (KokoMediaLibrary.asset(mediaAssetID) != nil && !KokoMediaLibrary.liveRoomPreviewAssetIDs.contains(mediaAssetID ?? "")) else {
            notice = "Add a caption of 1–1000 characters and choose a topic before submitting."
            return false
        }
        guard acceptsCommunityText(text) else { return false }
        let submission = PendingCommunityMoment(authorID: myID, caption: text, topic: topic, mediaAssetID: mediaAssetID)
        guard update({
            if $0.pendingMoments == nil { $0.pendingMoments = [] }
            $0.pendingMoments?.insert(submission, at: 0)
        }) else { return false }
        feedback = .init(title: "Saved for review", message: "Your post is saved privately and will appear only after review approval. The review service is not connected yet, so it has not been uploaded or published.", awaitingReview: true)
        return true
    }
}

enum KokoCommunityGuidelines {
    struct Section: Sendable { let title: String; let body: String }
    static var supportEmail: String? {
        guard Bundle.main.object(forInfoDictionaryKey: "KokoSafetySupportContactEnabled") as? Bool == true,
              let email = Bundle.main.object(forInfoDictionaryKey: "KokoSafetySupportEmail") as? String else { return nil }
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return address.isEmpty ? nil : address
    }
    static var sections: [Section] {
        var entries = communityRules
        if let email = supportEmail { entries.append(.init(title: "Support email", body: email)) }
        return entries
    }
    private static let communityRules: [Section] = [
        .init(title: "Adults, with accountable profiles", body: "Koko is for adults aged 18 and over. Use your own account and do not impersonate anyone. Random or anonymous matching is not offered. Never sexualize minors or share exploitative material."),
        .init(title: "A conversation takes two", body: "Private messages and calls require both people to follow each other. A follow never accepts for the other person. Respect a refusal, an unfollow or a block. Do not pressure anyone into contact, gifts or purchases."),
        .init(title: "Keep the room welcoming", body: "No harassment, hate, threats, bullying, pornography, exploitation, scams, illegal sales or encouragement of violence. Do not spam rooms or post deceptive links. Conversation, voice and video features are free."),
        .init(title: "Protect privacy and ownership", body: "Share only material you own or have permission to use. Do not publish another person's private details, images or recordings without consent. Never request passwords, payment credentials or intimate material."),
        .init(title: "Review before sharing", body: "New posts remain private while awaiting review. This build saves the review queue on your device and has no connected moderation service. It does not upload, approve or publicly publish queued posts."),
        .init(title: "Report, hide and block", body: "Choose Report on a profile, post, comment or conversation, select a reason and save it. Reported content disappears from your lists. Blocking hides that person's content and conversations. Unblocking does not restore a friendship."),
        .init(title: "What this build can do", body: "Reports, messages, follow choices and blocks are saved locally. Reports have not been sent to a moderation team, and no remote call or message delivery is claimed. A live service must provide moderation, timely report handling and verified support contact details before public operation."),
        .init(title: "If someone is in danger", body: "Do not use an in-app report for an emergency. Contact local emergency services when someone faces immediate danger. Preserve relevant information safely and do not repost harmful material.")
    ]
}
