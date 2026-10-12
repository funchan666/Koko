import SwiftUI

struct KokoConversationDiscoveryInvitation: View {
    @EnvironmentObject private var navigation: KokoSceneNavigation
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { navigation.open(.conversationStarters(nil)) } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 16) {
                        Text("A little icebreaker")
                            .font(KokoTypography.emphasis(size: 13, relativeTo: .subheadline))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image("KokoConversationDeckObject").resizable().scaledToFit()
                            .frame(width: 56, height: 56).accessibilityHidden(true)
                    }
                    Text("What small thing made your day better?")
                        .font(KokoTypography.handwritten(size: 30, relativeTo: .title2))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Open the deck →")
                        .font(KokoTypography.heading(size: 13, relativeTo: .body)).frame(minHeight: 44)
                }.foregroundStyle(KokoInk.canvas).padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background { Image("KokoConversationPromptPaper").resizable().accessibilityHidden(true) }
            }.buttonStyle(KokoPressStyle())
            Button { navigation.open(.sharedInterests) } label: {
                HStack(spacing: 14) {
                    Image("KokoSharedInterestObject").resizable().scaledToFit()
                        .frame(width: 52, height: 52).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Find your common ground").font(KokoTypography.heading(size: 17, relativeTo: .headline))
                        Text("Start with what you love").font(KokoTypography.medium(size: 12, relativeTo: .subheadline))
                            .foregroundStyle(KokoInk.secondary)
                    }.fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
                    Text("→").foregroundStyle(KokoInk.accent).accessibilityHidden(true)
                }.padding(.vertical, 8).contentShape(Rectangle())
            }.buttonStyle(KokoPressStyle())
        }
    }
}

// All decorative surfaces and semantic objects are original raster artwork.
// Text and hit targets remain native for localization and accessibility.
struct KokoConnectionEntry: View {
    @Environment(\.dynamicTypeSize) private var textSize
    let title: String
    let detail: String
    let artwork: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            let layout = textSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                : AnyLayout(HStackLayout(alignment: .center, spacing: 16))
            layout {
                Image(artwork).resizable().scaledToFit().frame(width: 68, height: 68).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(LocalizedStringKey(title)).font(KokoTypography.heading(size: 18, relativeTo: .headline))
                    Text(LocalizedStringKey(detail)).font(KokoTypography.medium(size: 12, relativeTo: .subheadline))
                        .foregroundStyle(KokoInk.canvas.opacity(0.72))
                }.fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
                Text("→").font(KokoTypography.emphasis(size: 20)).accessibilityHidden(true)
            }.foregroundStyle(KokoInk.canvas).padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background { Image("KokoCollectionMintSurface").resizable().accessibilityHidden(true) }
                .contentShape(Rectangle())
        }.buttonStyle(KokoPressStyle())
    }
}

struct KokoConversationStartersView: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    let recipientID: String?
    @State private var topic = "All"
    @State private var savedOnly = false
    @State private var selectedID: String?
    @State private var choosingFriend = false

    private var cards: [ConversationStarter] {
        ConversationStarter.collection.filter {
            (topic == "All" || $0.topic == topic) && (!savedOnly || community.savedConversationStarterIDs.contains($0.id))
        }
    }
    private var current: ConversationStarter? { cards.first { $0.id == selectedID } ?? cards.first }
    private var friends: [CommunityMember] { community.members.filter { community.friends.contains($0.id) } }

    var body: some View {
        ZStack {
            KokoPage(title: "A little icebreaker", subtitle: "Good conversations start with curiosity.", back: navigation.back) {
                HStack(alignment: .center, spacing: 16) {
                    Image("KokoConversationDeckObject").resizable().scaledToFit()
                        .frame(width: 80, height: 80).accessibilityHidden(true)
                    Text("Pick a question. Make it your own.")
                        .font(KokoTypography.emphasis(size: 19, relativeTo: .headline))
                        .fixedSize(horizontal: false, vertical: true)
                }
                KokoChoiceRail(choices: KokoCommunity.topics, selection: $topic)
                HStack {
                    Text("\(cards.count) questions").foregroundStyle(KokoInk.secondary)
                    Spacer(minLength: 12)
                    Button { savedOnly.toggle(); selectedID = nil } label: {
                        Text(LocalizedStringKey(savedOnly ? "Show all questions" : "Saved questions"))
                            .frame(minHeight: 44)
                    }.buttonStyle(KokoPressStyle()).foregroundStyle(KokoInk.accent)
                        .accessibilityAddTraits(savedOnly ? .isSelected : [])
                }.font(KokoTypography.emphasis(size: 13, relativeTo: .subheadline))

                if let starter = current {
                    questionCard(starter)
                    if let recipientID, !community.friends.contains(recipientID) {
                        Text("Become mutual friends before starting a chat.")
                            .font(KokoTypography.medium(size: 13, relativeTo: .body))
                        KokoAction(title: "Open profile") { navigation.open(.profile(recipientID)) }
                    } else {
                        KokoAction(title: "Use in a chat") {
                            if let recipientID { use(starter, with: recipientID) }
                            else { choosingFriend = true }
                        }
                    }
                    KokoAction(title: "Make a voice room", emphasis: false) {
                        navigation.open(.roomFromStarter(starter.id))
                    }
                    KokoAction(title: "Answer on my card", emphasis: false) {
                        navigation.open(.personalAnswers(starter.id))
                    }
                    Text("Questions are added to a draft. Nothing is sent automatically.")
                        .font(KokoTypography.medium(size: 12, relativeTo: .caption))
                        .foregroundStyle(KokoInk.secondary)
                } else {
                    Text("Keep a question for another hello.")
                        .font(KokoTypography.heading(size: 22, relativeTo: .title2))
                    Text("Save a card from any topic, then find it here.").foregroundStyle(KokoInk.secondary)
                    KokoAction(title: "Show all questions") { savedOnly = false; topic = "All" }
                }
            }.allowsHitTesting(!choosingFriend).accessibilityHidden(choosingFriend)
            if choosingFriend, let starter = current {
                KokoModal(title: "Who is this question for?", dismiss: { choosingFriend = false }) {
                    Text("Choose a mutual friend. You can review the draft before sending.")
                    ForEach(friends) { member in
                        HStack(spacing: 12) {
                            KokoProfileLink(memberID: member.id) {
                                HStack(spacing: 12) {
                                    KokoMemberPortrait(member: member).frame(width: 46, height: 46)
                                    Text(verbatim: member.publicName)
                                }
                            }
                            Spacer()
                            Button("Choose") { use(starter, with: member.id) }
                                .frame(minHeight: 44).buttonStyle(KokoPressStyle())
                        }.frame(minHeight: 54)
                    }
                    if friends.isEmpty {
                        Text("Your mutual friends will appear here.")
                        KokoAction(title: "Find shared interests") { choosingFriend = false; navigation.open(.sharedInterests) }
                    }
                }
            }
        }
    }

    private func questionCard(_ starter: ConversationStarter) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                Text(LocalizedStringKey(starter.topic))
                    .font(KokoTypography.emphasis(size: 12, relativeTo: .caption))
                Spacer(minLength: 8)
                Text("\((cards.firstIndex(of: starter) ?? 0) + 1) / \(cards.count)")
                    .font(KokoTypography.medium(size: 12, relativeTo: .caption))
            }
            Text(LocalizedStringKey(starter.question))
                .font(KokoTypography.handwritten(size: 34, relativeTo: .title))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 134, alignment: .leading)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 18) { saveButton(starter); nextButton(starter) }
                VStack(alignment: .leading, spacing: 6) { saveButton(starter); nextButton(starter) }
            }
        }.foregroundStyle(KokoInk.canvas).padding(26).padding(.bottom, 18)
            .background { Image("KokoConversationPromptPaper").resizable().accessibilityHidden(true) }
    }
    private func saveButton(_ starter: ConversationStarter) -> some View {
        Button { community.toggleConversationStarter(starter.id) } label: {
            Text(LocalizedStringKey(community.savedConversationStarterIDs.contains(starter.id) ? "Unsave question" : "Save question"))
                .font(KokoTypography.emphasis(size: 13, relativeTo: .body)).frame(minHeight: 44)
        }.buttonStyle(KokoPressStyle())
    }
    private func nextButton(_ starter: ConversationStarter) -> some View {
        Button {
            guard let index = cards.firstIndex(of: starter), cards.count > 1 else { return }
            selectedID = cards[(index + 1) % cards.count].id
        } label: {
            Text("Next question →").font(KokoTypography.heading(size: 13, relativeTo: .body)).frame(minHeight: 44)
        }.buttonStyle(KokoPressStyle()).disabled(cards.count < 2).opacity(cards.count < 2 ? 0.4 : 1)
    }
    private func use(_ starter: ConversationStarter, with memberID: String) {
        if community.prepareConversationStarter(starter.id, for: memberID) {
            choosingFriend = false
            if navigation.journey.dropLast().last == .conversation(memberID) { navigation.back() }
            else { navigation.open(.conversation(memberID)) }
        }
    }
}

struct KokoSharedInterestsView: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @State private var topic = "All"
    @State private var sharedOnly = true
    private var people: [CommunityMember] {
        community.members.filter {
            $0.id != community.myID && (topic == "All" || $0.interests.contains(topic))
                && (!sharedOnly || !community.sharedInterests(with: $0).isEmpty)
        }.sorted {
            let left = community.sharedInterests(with: $0).count
            let right = community.sharedInterests(with: $1).count
            return left == right ? $0.id < $1.id : left > right
        }
    }
    var body: some View {
        KokoPage(title: "Find your common ground", subtitle: "A shared interest is a good beginning.", back: navigation.back) {
            HStack(spacing: 16) {
                Image("KokoSharedInterestObject").resizable().scaledToFit().frame(width: 90, height: 90).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Start with what you love").font(KokoTypography.heading(size: 20, relativeTo: .headline))
                    Text("People are sorted by the interests you share.")
                        .font(KokoTypography.medium(size: 13, relativeTo: .body)).foregroundStyle(KokoInk.secondary)
                }.fixedSize(horizontal: false, vertical: true)
            }
            KokoChoiceRail(choices: KokoCommunity.topics, selection: $topic)
            KokoToggleRow(title: "Shared interests only", enabled: $sharedOnly)
            if community.currentMember?.interests.isEmpty != false {
                Text("Add your interests to find your common ground.")
                KokoAction(title: "Choose my interests") { navigation.open(.editProfile) }
            }
            ForEach(people) { member in
                personCard(member)
            }
            if people.isEmpty {
                Text("A different topic could be the start.").font(KokoTypography.heading(size: 21, relativeTo: .title2))
                KokoAction(title: "Explore all interests") { sharedOnly = false; topic = "All" }
            }
        }
    }
    private func personCard(_ member: CommunityMember) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Button { navigation.open(.profile(member.id)) } label: {
                HStack(alignment: .center, spacing: 14) {
                    KokoMemberPortrait(member: member).frame(width: 62, height: 74)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    VStack(alignment: .leading, spacing: 5) {
                        Text(verbatim: member.publicName).font(KokoTypography.heading(size: 20, relativeTo: .headline))
                        Text("View profile →").font(KokoTypography.emphasis(size: 12, relativeTo: .caption))
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.contentShape(Rectangle())
            }.buttonStyle(KokoPressStyle())
            let shared = community.sharedInterests(with: member)
            Text(LocalizedStringKey(shared.isEmpty ? "Explore their interests" : "Your common ground"))
                .font(KokoTypography.emphasis(size: 12, relativeTo: .caption))
            Text(verbatim: (shared.isEmpty ? member.interests : shared).map { KokoCopy.text($0) }.joined(separator: " · "))
                .font(KokoTypography.heading(size: 16, relativeTo: .body))
            Text(verbatim: member.introductionLine).font(KokoTypography.medium(size: 13, relativeTo: .body))
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 24) { follow(member); chat(member) }
                VStack(alignment: .leading, spacing: 0) { follow(member); chat(member) }
            }
        }.foregroundStyle(KokoInk.canvas).padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { Image("KokoDiscoverInvitationPaper").resizable().accessibilityHidden(true) }
    }
    private func follow(_ member: CommunityMember) -> some View {
        Button { community.toggleFollow(member.id) } label: {
            Text(LocalizedStringKey(community.following.contains(member.id) ? "Followed" : "Follow"))
                .font(KokoTypography.heading(size: 14, relativeTo: .body)).frame(minHeight: 44)
        }.buttonStyle(KokoPressStyle())
    }
    private func chat(_ member: CommunityMember) -> some View {
        Button { navigation.open(.conversationStarters(member.id)) } label: {
            Text("Choose an icebreaker →").font(KokoTypography.emphasis(size: 13, relativeTo: .body)).frame(minHeight: 44)
        }.buttonStyle(KokoPressStyle())
    }
}

struct KokoPersonalAnswersView: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    let initialStarterID: String?
    @State private var editing: ConversationStarter?
    @State private var answer = ""
    @State private var confirmRemoval = false
    @State private var confirmDiscard = false
    @State private var openedInitial = false
    private var answers: [String: String] { community.currentMember?.conversationAnswers ?? [:] }
    private var changed: Bool { editing.map { answer != (answers[$0.id] ?? "") } ?? false }

    var body: some View {
        ZStack {
            KokoPage(title: "In your own words", subtitle: "Give someone a reason to say hello.", back: navigation.back) {
                HStack(spacing: 16) {
                    Image("KokoPersonalAnswerObject").resizable().scaledToFit().frame(width: 84, height: 84).accessibilityHidden(true)
                    Text("Little answers. More you.").font(KokoTypography.heading(size: 23, relativeTo: .title2))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("Your saved answers appear on your profile. Choose only what you want to share.")
                    .font(KokoTypography.medium(size: 13, relativeTo: .body)).foregroundStyle(KokoInk.secondary)
                KokoAnswerCards(member: community.currentMember, edit: { startEditing($0) })
                if !answers.isEmpty {
                    KokoAction(title: "Preview my profile", emphasis: false) { navigation.open(.profile(community.myID)) }
                }
                Text("Pick a question").font(KokoTypography.heading(size: 20, relativeTo: .headline)).accessibilityAddTraits(.isHeader)
                ForEach(ConversationStarter.collection.filter { answers[$0.id] == nil }) { starter in
                    Button { startEditing(starter) } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(LocalizedStringKey(starter.topic)).font(KokoTypography.medium(size: 11, relativeTo: .caption))
                                .foregroundStyle(KokoInk.secondary)
                            Text(LocalizedStringKey(starter.question)).font(KokoTypography.emphasis(size: 16, relativeTo: .body))
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Write my answer →").font(KokoTypography.emphasis(size: 12, relativeTo: .caption))
                                .foregroundStyle(KokoInk.accent)
                        }.frame(maxWidth: .infinity, minHeight: 80, alignment: .leading).padding(.vertical, 8).contentShape(Rectangle())
                    }.buttonStyle(KokoPressStyle())
                }
            }.allowsHitTesting(editing == nil).accessibilityHidden(editing != nil)
            if let starter = editing {
                KokoModal(title: "Your answer", dismiss: { if changed { confirmDiscard = true } else { editing = nil } }) {
                    Text(LocalizedStringKey(starter.question)).font(KokoTypography.heading(size: 20, relativeTo: .headline))
                    KokoField(label: "Write in your own words", value: $answer, multiline: true)
                    Text("\(answer.count) / 240").font(KokoTypography.medium(size: 12, relativeTo: .caption))
                    KokoAction(title: "Save answer") {
                        if community.saveConversationAnswer(answer, starterID: starter.id) { editing = nil }
                    }.disabled(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || answer.count > 240)
                    if answers[starter.id] != nil {
                        if confirmRemoval {
                            Text("Remove this answer from your profile?")
                            KokoAction(title: "Remove answer", emphasis: false) {
                                if community.removeConversationAnswer(starter.id) { editing = nil }
                            }
                        } else {
                            KokoAction(title: "Remove answer", emphasis: false) { confirmRemoval = true }
                        }
                    }
                    if confirmDiscard {
                        Text("Leave without saving this answer?")
                        KokoAction(title: "Keep writing", emphasis: false) { confirmDiscard = false }
                        KokoAction(title: "Discard changes", emphasis: false) { editing = nil }
                    }
                }
            }
        }.onAppear {
            guard !openedInitial else { return }
            openedInitial = true
            if let starter = ConversationStarter.find(initialStarterID) { startEditing(starter) }
        }
    }
    private func startEditing(_ starter: ConversationStarter) {
        answer = answers[starter.id] ?? ""; confirmRemoval = false; confirmDiscard = false; editing = starter
    }
}

struct KokoAnswerCards: View {
    let member: CommunityMember?
    var edit: ((ConversationStarter) -> Void)? = nil
    var body: some View {
        ForEach(ConversationStarter.collection.filter { member?.conversationAnswers?[$0.id] != nil }) { starter in
            VStack(alignment: .leading, spacing: 12) {
                Text(LocalizedStringKey(starter.question)).font(KokoTypography.emphasis(size: 13, relativeTo: .subheadline))
                Text(verbatim: member?.conversationAnswers?[starter.id] ?? "")
                    .font(KokoTypography.heading(size: 21, relativeTo: .title3))
                    .fixedSize(horizontal: false, vertical: true)
                if let edit {
                    Button { edit(starter) } label: {
                        Text("Edit answer →").font(KokoTypography.emphasis(size: 12, relativeTo: .body)).frame(minHeight: 44)
                    }.buttonStyle(KokoPressStyle())
                }
            }.foregroundStyle(KokoInk.canvas).padding(24).padding(.bottom, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background { Image("KokoConversationPromptPaper").resizable().accessibilityHidden(true) }
        }
    }
}
