import Foundation

/// Curated sample engagement for the supplied media catalogue, separate from user writes.
enum KokoMomentConversationSeeds {
    private static let openingLines: [String: String] = [
        "city-notes": "The little stories between destinations are my favourite.",
        "photo-025842e859b26baa": "That orange tree makes this corner feel like a little escape.",
        "photo-387cfb0df9bf707a": "I had to look twice. I like that unexpected angle.",
        "photo-d1360451d8292f40": "The window seat is always my first choice too.",
        "photo-4c4cb4419a028e41": "I would happily take the longer route down that street.",
        "clip-727ad853dcc6c680": "That looks like a proper breath of fresh air.",
        "photo-3e29a87b4e9a5de9": "Terrace light like this makes it hard to leave.",
        "photo-f18f8ac9ab90dab5": "A view worth putting your phone down for after the photo.",
        "photo-d4df27b33da26d96": "The water looks like the perfect place to pause.",
        "photo-393c437ceadbdcb4": "No schedule, just a good place to wander.",
        "little-studio": "I like how you noticed something in an ordinary day.",
        "photo-0b85d7255a7f4aa3": "An afternoon without a timetable sounds good right now.",
        "photo-180dadb2a35776c8": "Those moments just before heading out have their own mood.",
        "photo-d3c3bb7d61690438": "Now I want to know what was playing in that room.",
        "photo-81de59ec5528ce00": "That looks like the table where the longest conversations happen.",
        "clip-0101e556a214b526": "One little light can change the whole mood.",
        "photo-d05bf869347edf23": "I needed a reminder to leave a pause between plans.",
        "photo-d50e16c961c48661": "A bag and an open afternoon. That is a good start.",
        "photo-64c61c1a1080d87d": "I could spend ages looking through those shelves.",
        "photo-c09d21c84b62e0aa": "This feels like the first page of a good evening.",
        "clip-6f8458f557ac70eb": "The kitchen breaks are sometimes the best part of the day.",
        "photo-50c1c44615fa556f": "A bit of open air can reset everything.",
        "photo-3ffecd4a84a17ccd": "I like that you kept both versions instead of choosing one.",
        "photo-11e15e298376a7d0": "That patch of sunlight would stop me in my tracks.",
        "photo-cb95a92b76ff26ba": "The long way is usually the one worth remembering.",
        "slow-morning": "A walk is such a good way to let a conversation wander.",
        "photo-90b3dd17963ade3f": "This makes the everyday noise feel a little farther away.",
        "photo-475a6aaf150f2fa1": "A small coffee ritual is a very good ritual.",
        "photo-764f948432c41f3b": "Those skies make tomorrow feel a little more open.",
        "photo-d89ae3bc08b1927a": "Sometimes the waiting becomes the nicest part.",
        "evening-record": "The best part of a table is the stories around it.",
        "photo-f56c3760c72ea322": "I always stay for the last story at dinner.",
        "photo-60fdc95bdde549d8": "An easy start is exactly what I want tomorrow.",
        "photo-34ec6f3593898b3c": "This has a lovely come-in-and-stay feeling.",
        "photo-e083ffbc6ca03436": "Those last colours never seem to last long enough.",
        "clip-3c0d55dae21cc5ab": "A trail and a good story make a nice pair.",
        "photo-8e3b83fc3a2dbf42": "The mist makes everything feel wonderfully quiet.",
        "photo-902371eab8c796f3": "A small change of angle really changes the feeling.",
        "photo-5c0da2b4e934f464": "Good company makes even the detours worthwhile.",
        "photo-6cf5a11ab933a864": "The green details are what caught my eye first.",
        "clip-2ade133c926cc675": "That blue is incredible. I watched it twice.",
        "photo-411a054c80274d17": "I love the little things you only see when you stop.",
        "photo-dd4b7eba252d137e": "All that blue makes the frame feel almost endless.",
        "photo-ac7422bbdf59203f": "A walk worth taking slowly, by the look of it.",
        "photo-d5ce66d2fa5d3061": "Finding a few favourites is better than rushing through everything.",
        "clip-624b4c415e314c5c": "I caught myself moving along to that rhythm.",
        "photo-90b59422592b04ae": "It is nice seeing a familiar street with fresh eyes.",
        "photo-e0d8335ac8b052f1": "The city seems to become a different place after sundown.",
        "photo-85fef1725610aea2": "Lights and water are such a good combination.",
        "photo-1d30d65888eeaf38": "A whole afternoon outside sounds like a small luxury.",
        "photo-49e209386910d672": "That sunlight makes a simple pause feel special.",
        "photo-0fce7368f1432d83": "I can almost hear how quiet that snowy path is.",
        "photo-45d2eec9629e984f": "I would choose the table nearest the water too.",
        "photo-e0209c87c400a9ad": "A little outdoor moment goes a long way.",
    ]

    private static let replies = [
        "What made you stop and capture this?",
        "This is a good reminder to notice the small things.",
        "I would love to hear the story behind this one.",
        "A little moment worth keeping.",
        "This has such an easy, unhurried feeling.",
        "Adding this to my list of things to make time for.",
        "Thanks for sharing a small piece of your day.",
        "The sort of thing I would send to a friend."
    ]

    static func comments(for momentID: String) -> [ConversationEntry] {
        guard let index = KokoMediaLibrary.assets.firstIndex(where: { $0.momentKey == momentID }),
              let opening = openingLines[momentID] else { return [] }
        let asset = KokoMediaLibrary.assets[index]
        let authors = KokoCommunity.members.filter { $0.id != asset.curatorMemberID }
        guard !authors.isEmpty else { return [] }
        return (0..<(2 + index % 3)).map { position in
            var comment = ConversationEntry(
                authorMemberID: authors[(index + position) % authors.count].id,
                messageText: position == 0 ? opening : replies[(index * 3 + position) % replies.count]
            )
            comment.id = "moment-seed-\(momentID)-\(position)"
            // Stable ordering without implying the sample comment just arrived.
            comment.postedAt = Date(timeIntervalSince1970: 0)
            return comment
        }
    }

    static func likeCount(for momentID: String) -> Int {
        guard let index = KokoMediaLibrary.assets.firstIndex(where: { $0.momentKey == momentID }) else { return 0 }
        return 9 + (index * 29 + index / 3 * 11) % 173
    }
}
