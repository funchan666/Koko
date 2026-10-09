import SwiftUI
import AVFoundation

struct KokoMomentDetail: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var playback = KokoMomentPlayback()
    let momentID: String
    @State private var commentDraft = ""
    @State private var safetyTarget: String?
    @State private var safetyMember = ""
    private var moment: SharedMoment? { community.moments.first { $0.id == momentID } }
    var body: some View {
        ZStack {
            KokoPage(title: "A moment", back: navigation.back) {
                if let moment {
                    if let asset = moment.mediaAsset {
                        if asset.isVideo {
                            ZStack {
                                if let player = playback.player { KokoMovieSurface(player: player) }
                                if !playback.hasStarted { KokoContentImage(asset: asset, fitInside: true) }
                            }.frame(height: 430)
                            HStack {
                                KokoAction(title: playback.isPlaying ? "Pause" : "Play", icon: 0) { playback.toggle() }
                                KokoAction(title: playback.isMuted ? "Sound on" : "Mute", emphasis: false) { playback.toggleMute() }
                            }
                            HStack {
                                KokoAction(title: "Back 10s", emphasis: false) { playback.seek(-10) }
                                KokoAction(title: "Forward 10s", emphasis: false) { playback.seek(10) }
                            }
                            Text("FILM · " + asset.durationLabel).font(.custom("AvenirNext-Medium", size: 11)).foregroundStyle(KokoInk.secondary)
                            if let playbackIssue = playback.playbackIssue {
                                Text(playbackIssue).font(.custom("AvenirNext-Regular", size: 13))
                                KokoAction(title: "Reload film", emphasis: false) { playback.load(asset) }
                            }
                        } else {
                            KokoContentImage(asset: asset, fullResolution: true, fitInside: true).frame(height: 430)
                        }
                    } else {
                        Artwork(sheet: .collection, tile: moment.coverTile).frame(height: 290)
                        Text("This item is not available in the bundled collection.")
                    }
                    Text(moment.captionLine).font(.custom("AvenirNext-Bold", size: 27))
                    if let member = community.member(moment.creatorMemberID) { KokoMemberRow(member: member) }
                    HStack {
                        KokoAction(title: community.journal?.likedMomentKeys.contains(moment.id) == true ? "Liked" : "Like", emphasis: false) { community.update { if $0.likedMomentKeys.contains(moment.id) { $0.likedMomentKeys.remove(moment.id) } else { $0.likedMomentKeys.insert(moment.id) } } }
                        KokoAction(title: community.journal?.savedMomentKeys.contains(moment.id) == true ? "Saved" : "Save", emphasis: false) { community.update { if $0.savedMomentKeys.contains(moment.id) { $0.savedMomentKeys.remove(moment.id) } else { $0.savedMomentKeys.insert(moment.id) } } }
                        KokoIconAction(icon: 11, label: "Report or block") { safetyMember = moment.creatorMemberID; safetyTarget = moment.id }
                    }
                    Text("What did it bring to mind?").font(.custom("AvenirNext-Bold", size: 20))
                    let comments = (community.journal?.momentComments[moment.id] ?? []).filter { !(community.journal?.hiddenContentKeys.contains($0.id) ?? false) }
                    if comments.isEmpty { Text("Your words can be the first. Comments stay with this moment.").font(.custom("AvenirNext-Regular", size: 14)).foregroundStyle(KokoInk.secondary) }
                    ForEach(comments) { comment in
                        KokoCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(community.member(comment.authorMemberID)?.publicName ?? "Guest").font(.custom("AvenirNext-DemiBold", size: 13))
                                Text(comment.messageText)
                                HStack {
                                    Text(comment.postedAt, style: .date).font(.custom("AvenirNext-Regular", size: 11)).foregroundStyle(KokoInk.secondary)
                                    Spacer()
                                    if comment.authorMemberID == community.myID {
                                        Button("Remove comment") { community.update { $0.momentComments[moment.id]?.removeAll { $0.id == comment.id } } }
                                            .font(.custom("AvenirNext-Medium", size: 11)).buttonStyle(.plain)
                                    } else { Button("Report") { safetyMember = comment.authorMemberID; safetyTarget = comment.id }.buttonStyle(.plain) }
                                }
                            }
                        }
                    }
                    KokoField(label: "Your comment · up to 500 characters", value: $commentDraft, multiline: true)
                    KokoAction(title: "Add comment", icon: 12) {
                        let text = commentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !text.isEmpty, text.count <= 500 else { community.notice = "Write a comment from 1 to 500 characters."; return }
                        let comment = ConversationEntry(authorMemberID: community.myID, messageText: text)
                        if community.update({ $0.momentComments[moment.id, default: []].append(comment) }) { commentDraft = "" }
                    }
                } else { KokoEmpty(title: "This moment is hidden", detail: "Choose another story from Discover.") }
            }
            if let target = safetyTarget { KokoSafetyPanel(subjectKey: target, memberID: safetyMember) { safetyTarget = nil } }
        }.onAppear { if let asset = moment?.mediaAsset, asset.isVideo { playback.load(asset) } }
            .onDisappear { playback.stop() }
            .onChange(of: moment?.id) { identifier in if identifier == nil { playback.stop() } }
            .onChange(of: safetyTarget) { target in if target != nil { playback.pause() } }
            .onChange(of: scenePhase) { phase in if phase != .active { playback.pause() } }
    }
}

@MainActor
final class KokoMomentPlayback: ObservableObject {
    @Published private(set) var player: AVPlayer?
    @Published private(set) var isPlaying = false
    @Published private(set) var isMuted = false
    @Published private(set) var hasStarted = false
    @Published private(set) var playbackIssue: String?
    private var endedObserver: NSObjectProtocol?
    private var failureObserver: NSObjectProtocol?
    private var itemObservation: NSKeyValueObservation?
    private var playbackRevision = UUID()

    func load(_ asset: CommunityMediaAsset) {
        stop()
        playbackIssue = nil; hasStarted = false
        guard asset.isVideo, let url = asset.sourceURL else {
            playbackIssue = "This film is missing from the collection."; return
        }
        let revision = playbackRevision
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.isMuted = isMuted
        self.player = player
        itemObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] _, _ in
            Task { @MainActor in
                guard let self, self.playbackRevision == revision else { return }
                if self.player?.currentItem?.status == .failed {
                    self.pause(); self.playbackIssue = "This film could not be opened. Try loading it again."
                }
            }
        }
        endedObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.playbackRevision == revision else { return }
                self.pause(); self.player?.seek(to: .zero); self.hasStarted = false
            }
        }
        failureObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.playbackRevision == revision else { return }
                self.pause(); self.playbackIssue = "Playback stopped. You can reload this film."
            }
        }
    }
    func toggle() {
        if isPlaying { pause(); return }
        guard let player, playbackIssue == nil else { return }
        player.play(); hasStarted = true; isPlaying = true
    }
    func toggleMute() { isMuted.toggle(); player?.isMuted = isMuted }
    func pause() { player?.pause(); isPlaying = false }
    func seek(_ delta: Double) {
        guard let player else { return }
        let duration = player.currentItem?.duration.seconds ?? 0
        guard duration.isFinite, duration > 0 else { return }
        let position = player.currentTime().seconds
        guard position.isFinite else { return }
        player.seek(to: CMTime(seconds: min(duration, max(0, position + delta)), preferredTimescale: 600))
    }
    func stop() {
        playbackRevision = UUID()
        pause()
        itemObservation?.invalidate(); itemObservation = nil
        if let endedObserver { NotificationCenter.default.removeObserver(endedObserver) }
        if let failureObserver { NotificationCenter.default.removeObserver(failureObserver) }
        endedObserver = nil; failureObserver = nil
        player?.replaceCurrentItem(with: nil); player = nil
    }
}

struct KokoMovieSurface: UIViewRepresentable {
    let player: AVPlayer
    var videoGravity: AVLayerVideoGravity = .resizeAspect
    func makeUIView(context: Context) -> KokoMovieLayerView { let view = KokoMovieLayerView(); view.movieLayer.videoGravity = videoGravity; view.movieLayer.player = player; return view }
    func updateUIView(_ view: KokoMovieLayerView, context: Context) { view.movieLayer.videoGravity = videoGravity; view.movieLayer.player = player }
    static func dismantleUIView(_ view: KokoMovieLayerView, coordinator: ()) { view.movieLayer.player = nil }
}

final class KokoMovieLayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var movieLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

struct KokoSavedMomentsView: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var navigation: KokoSceneNavigation
    var body: some View {
        KokoPage(title: "Worth coming back to", back: navigation.back) {
            let saved = community.moments.filter { community.journal?.savedMomentKeys.contains($0.id) == true }
            if saved.isEmpty { KokoEmpty(title: "Keep a little inspiration", detail: "Save a moment in Discover and it will be here.") }
            ForEach(saved) { KokoMomentCard(moment: $0) }
        }
    }
}
