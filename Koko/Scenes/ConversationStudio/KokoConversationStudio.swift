import SwiftUI

/// Original bitmaps include transparent export margins. Scale the complete image
/// behind the hit area; no cropping, masking, or pixel modification is applied.
private struct KokoStudioArtwork: View {
    let name: String
    let heightScale: CGFloat
    var body: some View {
        GeometryReader { geometry in
            Image(name).resizable()
                .frame(width: geometry.size.width, height: geometry.size.height * heightScale)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct KokoStudioAction: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(LocalizedStringKey(title)).font(KokoTypography.emphasis(size: 15))
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(KokoInk.canvas).padding(.horizontal, 24).padding(.vertical, 14)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background { KokoStudioArtwork(name: "KokoStudioCoralAction", heightScale: 2.22) }
                .contentShape(Rectangle())
        }.buttonStyle(KokoPressStyle())
    }
}

struct KokoStudioPaper<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .foregroundStyle(KokoInk.canvas).padding(20).padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { KokoStudioArtwork(name: "KokoStudioNoteSurface", heightScale: 1.10) }
    }
}

struct KokoStudioEntry: View {
    @EnvironmentObject private var navigation: KokoSceneNavigation
    var body: some View {
        Button { navigation.open(.conversationStudio(nil)) } label: {
            VStack(alignment: .leading, spacing: 5) {
                Text("Conversation studio").font(KokoTypography.heading(size: 18))
                Text("A few questions. A closer conversation.")
                    .font(KokoTypography.medium(size: 12))
            }
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(KokoInk.canvas)
            .padding(.leading, 90).padding(.trailing, 38).padding(.vertical, 16)
            .frame(maxWidth: 380, minHeight: 88, alignment: .leading)
            .background { KokoStudioArtwork(name: "KokoStudioInvitationStrip", heightScale: 1.86) }
            .contentShape(Rectangle())
        }.buttonStyle(KokoPressStyle())
            .accessibilityElement(children: .combine)
            .accessibilityHint(Text("Arrange a conversation"))
    }
}

struct KokoConversationStudio: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    let roomID: String?
    @State private var confirmEditionOwner: String?
    @State private var showsEditionQuestions = false
    private var hasConfirmation: Bool { confirmEditionOwner != nil }
    var body: some View {
        ZStack {
            KokoPage(title: "Conversation studio", subtitle: "Prepare. Listen. Remember.", back: navigation.back) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Start with a good question.").font(KokoTypography.heading(size: 23))
                    Text("Three prompts, space to listen, a thought to keep.")
                        .font(KokoTypography.body(size: 14)).foregroundStyle(KokoInk.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    KokoStudioAction(title: "Make a free plan") { create() }
                    Text("Writing, hosting cues and reflections are free.")
                        .font(KokoTypography.medium(size: 11)).foregroundStyle(KokoInk.secondary)
                }.padding(.bottom, 6)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your conversations").font(KokoTypography.heading(size: 20))
                    if community.conversationPlans.isEmpty {
                        KokoStudioPaper {
                            Text("Your next hello starts here.").font(KokoTypography.emphasis(size: 16))
                            Text("Create a plan above. Your questions and private notes will be kept here.")
                                .font(KokoTypography.body(size: 13)).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    ForEach(community.conversationPlans) { plan in
                        Button { navigation.open(.conversationPlan(plan.id, roomID)) } label: {
                            KokoStudioPaper {
                                Text(verbatim: plan.sessionTitle).font(KokoTypography.heading(size: 18))
                                    .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                                HStack(alignment: .firstTextBaseline) {
                                    Text(LocalizedStringKey(plan.hostingFinishedAt != nil ? "Reflection" : plan.isActive ? "Hosting cues" : "Draft plan"))
                                    Spacer(minLength: 8)
                                    Text(plan.lastEditedAt, style: .date)
                                }.font(KokoTypography.medium(size: 11))
                            }.contentShape(Rectangle())
                        }.buttonStyle(KokoPressStyle())
                    }
                }
                edition
                Text("Plans and unlocks stay in this account on this device. No broadcast or invitation is sent. Deleting the account or app data removes them.")
                    .font(KokoTypography.medium(size: 11)).foregroundStyle(KokoInk.secondary)
            }.allowsHitTesting(!hasConfirmation).accessibilityHidden(hasConfirmation)
            if let owner = confirmEditionOwner {
                KokoModal(title: "Unlock Music memories?", dismiss: { confirmEditionOwner = nil }) {
                    Text("80 coins once. Six original questions in two editable hosting sequences. No random reward, subscription or expiry.")
                    Text("Your free plans, notes and conversations remain free. This unlock is stored on this device.")
                    KokoStudioAction(title: "Confirm · 80 coins") {
                        confirmEditionOwner = nil
                        _ = community.unlockMusicEdition(ownerID: owner)
                    }.disabled(community.purchaseInProgress)
                }
            }
        }
    }
    private var edition: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                Image("KokoConversationMusicEdition").resizable().scaledToFit()
                    .frame(width: 86).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Music memories").font(KokoTypography.heading(size: 19))
                    Text("Six questions. Two ways to connect.")
                        .font(KokoTypography.medium(size: 12)).foregroundStyle(KokoInk.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text("Two conversations about the people, places and memories inside a song. Music recordings are not included.")
                .font(KokoTypography.body(size: 13)).foregroundStyle(KokoInk.secondary)
            Button {
                showsEditionQuestions.toggle()
            } label: {
                Text(LocalizedStringKey(showsEditionQuestions ? "Hide the questions" : "Read all six questions"))
                    .font(KokoTypography.emphasis(size: 13)).foregroundStyle(KokoInk.accent)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }.buttonStyle(KokoPressStyle())
                .accessibilityValue(Text(LocalizedStringKey(showsEditionQuestions ? "Expanded" : "Collapsed")))
            // Exact contents remain available before any spend confirmation.
            if showsEditionQuestions {
                ForEach(Array(ConversationEditions.music.enumerated()), id: \.offset) { index, question in
                    HStack(alignment: .top, spacing: 12) {
                        Text(String(index + 1)).font(KokoTypography.heading(size: 15)).foregroundStyle(KokoInk.accent)
                        Text(LocalizedStringKey(question)).font(KokoTypography.body(size: 14))
                    }
                }
            }
            if community.ownsMusicEdition {
                Text("Unlocked · use as often as you like").font(KokoTypography.emphasis(size: 12))
                KokoStudioAction(title: "The room inside a song") { create(sequence: 0) }
                KokoStudioAction(title: "A song someone gave you") { create(sequence: 1) }
            } else {
                KokoStudioAction(title: "Unlock edition · 80 coins") { confirmEditionOwner = community.myID }
            }
        }.padding(.vertical, 12)
    }
    private func create(sequence: Int? = nil) {
        if let id = community.createConversationPlan(musicSequence: sequence) {
            navigation.open(.conversationPlan(id, roomID))
        }
    }
}

struct KokoConversationPlanView: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    let planID: String
    let suggestedRoomID: String?
    @State private var confirmation: String?
    private var plan: ConversationRunSheet? { community.conversationPlan(planID) }
    private var ownRooms: [HostedConversationRoom] {
        community.rooms.filter { $0.hostMemberID == community.myID && !$0.isVideoStage && community.activeConversationPlan(in: $0.id) == nil }
    }
    var body: some View {
        ZStack {
            KokoPage(title: "Your conversation", subtitle: "Private notes · saved as you write", back: navigation.back) {
                if let plan {
                    if plan.hostingStartedAt == nil { editor(plan) }
                    else if plan.isActive { hosting(plan) }
                    else { reflection(plan) }
                    Text("Plans and unlocks stay in this account on this device. No broadcast or invitation is sent. Deleting the account or app data removes them.")
                        .font(KokoTypography.medium(size: 12)).foregroundStyle(KokoInk.secondary)
                    Button("Delete this plan") { confirmation = "delete" }
                        .font(KokoTypography.emphasis(size: 14)).foregroundStyle(KokoInk.coral)
                        .frame(minHeight: 48).buttonStyle(KokoPressStyle())
                } else { Text("This plan is no longer available.") }
            }.allowsHitTesting(confirmation == nil).accessibilityHidden(confirmation != nil)
            if let confirmation {
                KokoModal(title: confirmation == "delete" ? "Delete this plan?" : "Keep a reflection?", dismiss: { self.confirmation = nil }) {
                    Text(LocalizedStringKey(confirmation == "delete" ? "This removes its questions and private notes. Your room and edition unlock are kept." : "Finish the cue sequence and write what you want to remember. Nothing is posted."))
                    KokoStudioAction(title: confirmation == "delete" ? "Delete this plan" : "Finish and reflect") {
                        self.confirmation = nil
                        if confirmation == "delete" {
                            if community.deleteConversationPlan(planID) { navigation.back() }
                        } else { _ = community.finishConversationPlan(planID) }
                    }
                }
            }
        }
    }
    private func editor(_ plan: ConversationRunSheet) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            field("Plan title · 60 characters", binding(\.sessionTitle))
            ForEach(0..<3, id: \.self) { index in
                KokoStudioPaper {
                    Text(LocalizedStringKey(ConversationRunSheet.stages[index])).font(KokoTypography.heading(size: 20))
                    TextField(KokoCopy.text("Your question · 240 characters"), text: questionBinding(index), axis: .vertical)
                        .textFieldStyle(.plain).font(KokoTypography.handwritten(size: 25))
                        .tint(KokoInk.canvas).lineLimit(2...6)
                        .accessibilityLabel(Text(LocalizedStringKey(ConversationRunSheet.stages[index])))
                    HStack {
                        if index > 0 { Button("Move earlier") { swap(index, index - 1) }.frame(minHeight: 44) }
                        Spacer()
                        if index < 2 { Button("Move later") { swap(index, index + 1) }.frame(minHeight: 44) }
                    }.font(KokoTypography.emphasis(size: 12)).buttonStyle(KokoPressStyle())
                }
            }
            Text("Choose where to use your cues").font(KokoTypography.heading(size: 21))
            KokoStudioAction(title: "Start private cue board") { _ = community.beginConversationPlan(planID, roomID: nil) }
            ForEach(ownRooms.sorted { ($0.id == suggestedRoomID ? 0 : 1) < ($1.id == suggestedRoomID ? 0 : 1) }) { room in
                VStack(alignment: .leading, spacing: 8) {
                    Text(verbatim: room.roomTitle).font(KokoTypography.emphasis(size: 17))
                    KokoStudioAction(title: "Use in this voice room") { _ = community.beginConversationPlan(planID, roomID: room.id) }
                }
            }
            if ownRooms.isEmpty {
                Text("Create your own voice room to attach a plan. A private cue board also works for an in-person conversation.").font(KokoTypography.body(size: 14))
                KokoStudioAction(title: "Create a voice room") { navigation.open(.createRoom(false)) }
            }
        }
    }
    private func hosting(_ plan: ConversationRunSheet) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(verbatim: plan.sessionTitle).font(KokoTypography.heading(size: 25))
            KokoStudioPaper {
                Text("\(plan.activePromptIndex + 1) / 3").font(KokoTypography.emphasis(size: 13))
                Text(LocalizedStringKey(ConversationRunSheet.stages[plan.activePromptIndex])).font(KokoTypography.emphasis(size: 15))
                Text(verbatim: plan.orderedPrompts[plan.activePromptIndex]).font(KokoTypography.handwritten(size: 32))
                    .fixedSize(horizontal: false, vertical: true)
                Text("Invite a story. Leave space to pass.").font(KokoTypography.medium(size: 13))
            }
            field("Private listening note · 1,000 characters", noteBinding(plan.activePromptIndex))
            if plan.activePromptIndex > 0 {
                KokoStudioAction(title: "Previous question") { _ = community.moveConversationPlan(planID, step: plan.activePromptIndex - 1) }
            }
            if plan.activePromptIndex < 2 {
                KokoStudioAction(title: "Next question") { _ = community.moveConversationPlan(planID, step: plan.activePromptIndex + 1) }
            }
            if let roomID = plan.linkedRoomID, community.room(roomID) != nil {
                KokoStudioAction(title: "Return to voice room") { navigation.open(.room(roomID)) }
            }
            KokoStudioAction(title: "Finish and reflect") { confirmation = "finish" }
        }
    }
    private func reflection(_ plan: ConversationRunSheet) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            KokoStudioPaper {
                Text("A thread to keep").font(KokoTypography.heading(size: 29))
                Text(verbatim: plan.sessionTitle).font(KokoTypography.emphasis(size: 17))
                Text("Your notes belong to you. Save a thought, not a transcript of someone else.").font(KokoTypography.body(size: 14))
            }
            ForEach(0..<3, id: \.self) { index in
                Text(verbatim: plan.orderedPrompts[index]).font(KokoTypography.emphasis(size: 17))
                field("Private listening note · 1,000 characters", noteBinding(index))
            }
            field("What I want to remember · 2,000 characters", binding(\.personalReflection))
            field("A question for next time · 240 characters", binding(\.followUpPrompt))
            if !plan.followUpPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                KokoStudioAction(title: "Make this the next conversation") {
                    if let id = community.continueConversationPlan(planID) {
                        navigation.open(.conversationPlan(id, nil))
                    }
                }
            }
        }
    }
    private func field(_ label: String, _ value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey(label)).font(KokoTypography.emphasis(size: 13))
            TextField(KokoCopy.text(label), text: value, axis: .vertical)
                .textFieldStyle(.plain).font(KokoTypography.body(size: 17)).lineLimit(2...8)
                .foregroundStyle(KokoInk.canvas).tint(KokoInk.canvas)
                .padding(20).padding(.bottom, 8)
                .background { KokoStudioArtwork(name: "KokoStudioNoteSurface", heightScale: 1.10) }
        }
    }
    private func binding(_ path: WritableKeyPath<ConversationRunSheet, String>) -> Binding<String> {
        let owner = community.myID
        return Binding(get: { community.conversationPlan(planID)?[keyPath: path] ?? "" }, set: { value in
            _ = community.editConversationPlan(planID, ownerID: owner) { $0[keyPath: path] = value }
        })
    }
    private func questionBinding(_ index: Int) -> Binding<String> {
        let owner = community.myID
        return Binding(get: { plan?.orderedPrompts[index] ?? "" }, set: { value in
            _ = community.editConversationPlan(planID, ownerID: owner) { $0.orderedPrompts[index] = value }
        })
    }
    private func noteBinding(_ index: Int) -> Binding<String> {
        let owner = community.myID
        return Binding(get: { plan?.listeningNotes[index] ?? "" }, set: { value in
            _ = community.editConversationPlan(planID, ownerID: owner) { $0.listeningNotes[index] = value }
        })
    }
    private func swap(_ first: Int, _ second: Int) {
        _ = community.editConversationPlan(planID, ownerID: community.myID) {
            $0.orderedPrompts.swapAt(first, second)
            $0.listeningNotes.swapAt(first, second)
        }
    }
}
