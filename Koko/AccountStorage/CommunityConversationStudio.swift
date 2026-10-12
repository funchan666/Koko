import Foundation

@MainActor
extension CommunityJournalStore {
    var conversationPlans: [ConversationRunSheet] {
        (journal?.conversationPlans ?? []).sorted { $0.lastEditedAt > $1.lastEditedAt }
    }
    var ownsMusicEdition: Bool {
        journal?.conversationEditionIDs?.contains(ConversationEditions.musicEditionID) ?? false
    }
    func conversationPlan(_ id: String) -> ConversationRunSheet? {
        journal?.conversationPlans?.first { $0.id == id }
    }
    func activeConversationPlan(in roomID: String) -> ConversationRunSheet? {
        conversationPlans.first { $0.linkedRoomID == roomID && $0.isActive }
    }

    @discardableResult
    func unlockMusicEdition(ownerID: String) -> Bool {
        guard hasCurrentPolicyConsent, hasCompletedAccountEntry, myID == ownerID, accountDeparture == nil, !purchaseInProgress else { return false }
        guard !ownsMusicEdition else { return true }
        let cost = ConversationEditions.musicPrice
        guard (journal?.coinBalance ?? 0) >= cost else {
            coinShortfall = .init(requiredCoins: cost, purpose: KokoCopy.text("Music memories"))
            return false
        }
        let saved = update {
            $0.conversationEditionIDs = ($0.conversationEditionIDs ?? []).union([ConversationEditions.musicEditionID])
            $0.coinBalance = ($0.coinBalance ?? 0) - cost
            $0.walletHistory.insert(.init(entryDescription: KokoCopy.text("Music memories · one-time edition"), coinDelta: -cost), at: 0)
        }
        if saved { feedback = .init(title: "Edition unlocked", message: "Six music questions and two hosting sequences are ready. Reusing them is free.") }
        return saved
    }

    @discardableResult
    func createConversationPlan(musicSequence: Int? = nil) -> String? {
        guard journal != nil, accountDeparture == nil else { return nil }
        var questions = ConversationEditions.everyday
        var title = "A conversation worth keeping"
        if let sequence = musicSequence {
            guard ownsMusicEdition, (0...1).contains(sequence) else { return nil }
            questions = Array(ConversationEditions.music[(sequence * 3)..<(sequence * 3 + 3)])
            title = sequence == 0 ? "The room inside a song" : "A song someone gave you"
        }
        let plan = ConversationRunSheet(sessionTitle: KokoCopy.text(title), orderedPrompts: questions.map { KokoCopy.text($0) })
        return update { $0.conversationPlans = ($0.conversationPlans ?? []) + [plan] } ? plan.id : nil
    }

    @discardableResult
    func editConversationPlan(_ id: String, ownerID: String, change: (inout ConversationRunSheet) -> Void) -> Bool {
        guard myID == ownerID, accountDeparture == nil, var plan = conversationPlan(id) else { return false }
        change(&plan)
        plan.sessionTitle = String(plan.sessionTitle.prefix(60))
        plan.orderedPrompts = plan.orderedPrompts.map { String($0.prefix(240)) }
        plan.listeningNotes = plan.listeningNotes.map { String($0.prefix(1000)) }
        plan.personalReflection = String(plan.personalReflection.prefix(2000))
        plan.followUpPrompt = String(plan.followUpPrompt.prefix(240))
        guard plan.orderedPrompts.count == 3, plan.listeningNotes.count == 3, (0..<3).contains(plan.activePromptIndex) else { return false }
        plan.lastEditedAt = Date()
        return update { value in
            guard let index = value.conversationPlans?.firstIndex(where: { $0.id == id }) else { return }
            value.conversationPlans?[index] = plan
        }
    }

    @discardableResult
    func beginConversationPlan(_ id: String, roomID: String?) -> Bool {
        guard accountDeparture == nil, var plan = conversationPlan(id), plan.hostingStartedAt == nil else { return false }
        guard !plan.sessionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              plan.orderedPrompts.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            notice = "Add a title and all three questions before starting."
            return false
        }
        var linkedRoom: HostedConversationRoom?
        if let roomID {
            guard plan.orderedPrompts.allSatisfy({ acceptsCommunityText($0) }) else { return false }
            guard let room = room(roomID), room.hostMemberID == myID, !room.isVideoStage,
                  activeConversationPlan(in: roomID) == nil else {
                notice = "Choose your own voice room without an active plan."
                return false
            }
            linkedRoom = room
        }
        plan.hostingStartedAt = Date(); plan.lastEditedAt = Date(); plan.linkedRoomID = roomID
        return update { value in
            guard let index = value.conversationPlans?.firstIndex(where: { $0.id == id }) else { return }
            value.conversationPlans?[index] = plan
            if var room = linkedRoom {
                room.conversationPrompt = plan.orderedPrompts[0]
                value.roomOverrides[room.id] = room
            }
        }
    }

    @discardableResult
    func moveConversationPlan(_ id: String, step: Int) -> Bool {
        guard accountDeparture == nil, var plan = conversationPlan(id), plan.isActive,
              plan.orderedPrompts.count == 3, (0..<3).contains(step) else { return false }
        if plan.linkedRoomID != nil, !acceptsCommunityText(plan.orderedPrompts[step]) { return false }
        plan.activePromptIndex = step; plan.lastEditedAt = Date()
        return update { value in
            guard let index = value.conversationPlans?.firstIndex(where: { $0.id == id }) else { return }
            value.conversationPlans?[index] = plan
            if let roomID = plan.linkedRoomID, var room = room(roomID), room.hostMemberID == myID {
                room.conversationPrompt = plan.orderedPrompts[step]
                value.roomOverrides[roomID] = room
            }
        }
    }

    @discardableResult
    func finishConversationPlan(_ id: String) -> Bool {
        guard conversationPlan(id)?.isActive == true else { return false }
        return editConversationPlan(id, ownerID: myID) { $0.hostingFinishedAt = Date() }
    }

    @discardableResult
    func continueConversationPlan(_ id: String) -> String? {
        guard accountDeparture == nil, let previous = conversationPlan(id), previous.hostingFinishedAt != nil else { return nil }
        let question = previous.followUpPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return nil }
        var questions = ConversationEditions.everyday.map { KokoCopy.text($0) }
        questions[0] = String(question.prefix(240))
        let next = ConversationRunSheet(sessionTitle: previous.sessionTitle, orderedPrompts: questions)
        return update { $0.conversationPlans = ($0.conversationPlans ?? []) + [next] } ? next.id : nil
    }

    @discardableResult
    func deleteConversationPlan(_ id: String) -> Bool {
        guard journal != nil, accountDeparture == nil else { return false }
        return update { $0.conversationPlans?.removeAll { $0.id == id } }
    }
}
