import SwiftUI

struct KokoKeepsakeCollection: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    let backpack: Bool
    @State private var chosen: RoomKeepsake?
    @State private var category = "All"
    private var keepsakes: [RoomKeepsake] {
        KokoCommunity.keepsakes.filter { (!backpack || (community.journal?.ownedKeepsakes[$0.id] ?? 0) > 0) && (category == "All" || (category == "Wearables" ? $0.wearable : !$0.wearable)) }
    }
    var body: some View {
        ZStack {
            KokoPage(title: backpack ? "Little things, kept close" : "The little shop", subtitle: backpack ? "Your personal backpack" : "Original keepsakes for your Koko world", back: navigation.back) {
                HStack { Text("Balance · \(community.coinBalance) coins").font(.custom("AvenirNext-DemiBold", size: 14)); Spacer(); Button("Add coins") { navigation.open(.wallet) }.buttonStyle(.plain).font(.custom("AvenirNext-Bold", size: 14)).padding(.vertical, 12) }
                KokoChoiceRail(choices: ["All", "Wearables", "Gifts"], selection: $category)
                if keepsakes.isEmpty { KokoEmpty(title: "Room for a little something", detail: "Pick a keepsake from the shop and find it here."); KokoAction(title: "Visit the shop", icon: 8) { navigation.open(.shop) } }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(keepsakes) { keepsake in
                        Button { chosen = keepsake } label: {
                            VStack(spacing: 10) {
                                Artwork(sheet: .collection, tile: keepsake.artworkTile).frame(height: 125)
                                Text(keepsake.keepsakeName).font(.custom("AvenirNext-DemiBold", size: 14))
                                Text(backpack ? "Owned ×\(community.journal?.ownedKeepsakes[keepsake.id] ?? 0)" : "\(keepsake.tokenCost) coins").font(.custom("AvenirNext-Regular", size: 11)).foregroundStyle(KokoInk.secondary)
                                if community.journal?.wornKeepsakeID == keepsake.id { Text("Wearing now").font(.custom("AvenirNext-Bold", size: 10)) }
                            }.padding(14).frame(maxWidth: .infinity).background(ArtworkSurface())
                        }.buttonStyle(KokoPressStyle())
                    }
                }
            }
            if let keepsake = chosen {
                KokoModal(title: keepsake.keepsakeName, dismiss: { chosen = nil }) {
                    Artwork(sheet: .collection, tile: keepsake.artworkTile).frame(height: 190)
                    if backpack {
                        if keepsake.wearable {
                            KokoAction(title: community.journal?.wornKeepsakeID == keepsake.id ? "Take it off" : "Wear on my profile") { community.update { $0.wornKeepsakeID = $0.wornKeepsakeID == keepsake.id ? nil : keepsake.id }; chosen = nil }
                        } else {
                            Text("Gift one from your backpack to a room. This uses one owned item without spending more coins.")
                            ForEach(community.rooms) { room in
                                KokoAction(title: "Give to " + room.roomTitle, emphasis: false) {
                                    let sender = community.myID
                                    community.update {
                                        guard ($0.ownedKeepsakes[keepsake.id] ?? 0) > 0 else { return }
                                        $0.ownedKeepsakes[keepsake.id, default: 0] -= 1
                                        var changed = $0.roomOverrides[room.id] ?? room
                                        changed.roomConversation.append(.init(authorMemberID: sender, messageText: "Gifted \(keepsake.keepsakeName) from backpack", attachmentTile: keepsake.artworkTile))
                                        $0.roomOverrides[room.id] = changed
                                    }
                                    chosen = nil
                                }
                            }
                        }
                    } else {
                        Text("\(keepsake.tokenCost) coins · saved to your backpack")
                        KokoAction(title: "Get this keepsake", icon: 8) { community.requestKeepsake(keepsake); chosen = nil }
                    }
                }
            }
        }
    }
}

struct KokoCheckInView: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    var body: some View {
        KokoPage(title: "A small daily ritual", back: navigation.back) {
            Artwork(sheet: .scenes, tile: 3).frame(height: 230)
            Text("Glad you stopped by.").font(.custom("AvenirNext-Bold", size: 29))
            Text("Every day you check in adds 10 activity points. Once a day, at your own pace.")
            KokoCard(tint: 3) { HStack { VStack(alignment: .leading) { Text("\(community.journal?.checkInDayKeys.count ?? 0)").font(.custom("AvenirNext-Bold", size: 42)); Text("days you made a little time") }; Spacer(); Artwork(sheet: .collection, tile: 13).frame(width: 90, height: 90) } }
            KokoAction(title: community.checkedInToday ? "You're checked in today" : "Save today's visit", icon: 15) { community.checkIn() }
            Text("Your visits").font(.custom("AvenirNext-Bold", size: 20))
            ForEach((community.journal?.checkInDayKeys ?? []).sorted().reversed(), id: \.self) { date in KokoCard { HStack { Text(date); Spacer(); Text("+10 points").font(.custom("AvenirNext-DemiBold", size: 13)) } } }
        }
    }
}

struct KokoLevelView: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    var body: some View {
        KokoPage(title: "Growing into your space", back: navigation.back) {
            Artwork(sheet: .collection, tile: 12).frame(height: 205)
            Text("Level \(community.activityLevel)").font(.custom("AvenirNext-Bold", size: 42))
            Text("\(community.activityPoints) activity points · \(200 - community.activityPoints % 200) to your next level")
            KokoCard { VStack(alignment: .leading, spacing: 12) { Text("A little goes a long way").font(.custom("AvenirNext-Bold", size: 21)); Text("Daily check-in: +10 points"); Text("Create a room: +20 points"); Text("Every 200 points opens the next level.").foregroundStyle(KokoInk.secondary) } }
            KokoAction(title: "Check in today", icon: 15) { navigation.open(.checkIn) }
        }
    }
}

struct KokoRankingView: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @State private var category = "Rooms"
    var body: some View {
        KokoPage(title: "Good company, celebrated", back: navigation.back) {
            Artwork(sheet: .navigation, tile: 15).frame(height: 140)
            KokoChoiceRail(choices: ["Rooms", "My activity", "My gifts"], selection: $category)
            if category == "Rooms" {
                ForEach(Array(community.rooms.sorted { $0.seatAssignments.count > $1.seatAssignments.count }.enumerated()), id: \.element.id) { index, room in
                    HStack { Text(String(format: "%02d", index + 1)).font(.custom("AvenirNext-Bold", size: 23)); KokoRoomCard(room: room) }
                }
            } else if category == "My activity" {
                KokoCard(tint: 3) { VStack(alignment: .leading, spacing: 10) { Text("\(community.activityPoints) points").font(.custom("AvenirNext-Bold", size: 32)); Text("Level \(community.activityLevel) · Your activity") } }
            } else {
                let records = (community.journal?.walletHistory ?? []).filter { $0.tokenChange < 0 }
                if records.isEmpty { KokoEmpty(title: "A gesture waiting to happen", detail: "Your gift and keepsake contributions appear here.") }
                ForEach(records) { record in KokoCard { HStack { Text(record.detailLine); Spacer(); Text("\(-record.tokenChange)") } } }
            }
        }
    }
}
