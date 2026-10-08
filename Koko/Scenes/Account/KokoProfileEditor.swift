import SwiftUI
import PhotosUI

struct KokoProfileEditor: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var journey: KokoAccessJourney
    let isOnboarding: Bool
    var onFinish: (() -> Void)? = nil
    @State private var draft: CommunityMember?
    @State private var displayName = ""
    @State private var gender = ""
    @State private var countryCode = ""
    @State private var birthYear = ""
    @State private var birthMonth = ""
    @State private var birthDay = ""
    @State private var introduction = ""
    @State private var chosenInterests: Set<String> = []
    @State private var portraitTile = 0
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var portraitJPEG: Data?
    @State private var usingArtwork = false
    @State private var importingPhoto = false
    @State private var showingCamera = false
    @State private var choosingCountry = false
    @State private var countryQuery = ""
    @State private var portraitRevision = UUID()
    private let interestOptions = ["Music", "Conversation", "Creative", "After hours", "Travel", "Films", "Food", "Books"]
    private var countryName: String { Locale(identifier: "en").localizedString(forRegionCode: countryCode) ?? "Choose country or region" }
    private var countryChoices: [String] {
        Locale.isoRegionCodes.filter { code in
            countryQuery.isEmpty || code.localizedCaseInsensitiveContains(countryQuery) || (Locale(identifier: "en").localizedString(forRegionCode: code) ?? code).localizedCaseInsensitiveContains(countryQuery)
        }.sorted { (Locale(identifier: "en").localizedString(forRegionCode: $0) ?? $0) < (Locale(identifier: "en").localizedString(forRegionCode: $1) ?? $1) }
    }
    var body: some View {
        ZStack {
            KokoPage(title: isOnboarding ? "Make it yours" : "Your little details", subtitle: isOnboarding ? "YOUR NAME. YOUR COMPANY. YOUR RHYTHM." : "A space that feels like you", back: isOnboarding ? nil : onFinish) {
                HStack(spacing: 20) {
                    portrait.frame(width: 105, height: 126).clipped()
                    VStack(alignment: .leading, spacing: 7) {
                        Text("A face to\nthe hello.").font(.custom("AvenirNext-Bold", size: 25))
                        Text("Choose a photo, or keep an original Koko portrait.").font(.custom("AvenirNext-Regular", size: 12)).foregroundStyle(KokoInk.secondary)
                    }
                }
                HStack(spacing: 8) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                        Text(importingPhoto ? "Opening photo…" : "Choose photo").font(.custom("AvenirNext-DemiBold", size: 14)).foregroundStyle(KokoInk.primary)
                            .frame(maxWidth: .infinity, minHeight: 50).background(ArtworkSurface(tile: 3))
                    }.buttonStyle(KokoPressStyle()).disabled(importingPhoto)
                    KokoAction(title: "Take photo", emphasis: false) { showingCamera = true }.disabled(importingPhoto)
                }
                HStack(spacing: 8) {
                    ForEach(0..<4) { tile in
                        Button {
                            portraitRevision = UUID(); selectedPhoto = nil; importingPhoto = false
                            portraitTile = tile; usingArtwork = true; portraitJPEG = nil
                        } label: {
                            Artwork(sheet: .collection, tile: tile).frame(width: 48, height: 52).padding(5)
                                .background(ArtworkSurface(tile: usingArtwork && portraitTile == tile ? 3 : 2))
                        }.buttonStyle(KokoPressStyle()).accessibilityLabel("Koko portrait \(tile + 1)")
                    }
                }
                KokoField(label: "Display name · required", value: $displayName)
                Text("How do you describe yourself? · required").font(.custom("AvenirNext-DemiBold", size: 12)).foregroundStyle(KokoInk.secondary)
                KokoChoiceRail(choices: ["Woman", "Man", "Non-binary", "Prefer not to say"], selection: $gender)
                KokoMenuRow(title: countryCode.isEmpty ? "Choose country or region" : countryName, detail: "Country or region · required", icon: 3) { countryQuery = ""; choosingCountry = true }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Date of birth · required").font(.custom("AvenirNext-DemiBold", size: 12)).foregroundStyle(KokoInk.secondary)
                    HStack(spacing: 8) {
                        KokoField(label: "Year · YYYY", value: $birthYear, keyboard: .numberPad)
                        KokoField(label: "Month · MM", value: $birthMonth, keyboard: .numberPad)
                        KokoField(label: "Day · DD", value: $birthDay, keyboard: .numberPad)
                    }
                    Text("For ages 18 and over. Your full birthday is kept private.").font(.custom("AvenirNext-Regular", size: 11)).foregroundStyle(KokoInk.secondary)
                }
                Text("Your conversation starters · choose at least one").font(.custom("AvenirNext-DemiBold", size: 12)).foregroundStyle(KokoInk.secondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(interestOptions, id: \.self) { interest in
                        Button { if chosenInterests.contains(interest) { chosenInterests.remove(interest) } else { chosenInterests.insert(interest) } } label: {
                            Text(interest).font(.custom("AvenirNext-DemiBold", size: 13)).frame(maxWidth: .infinity, minHeight: 46)
                                .background(ArtworkSurface(tile: chosenInterests.contains(interest) ? 3 : 2))
                        }.buttonStyle(KokoPressStyle()).accessibilityAddTraits(chosenInterests.contains(interest) ? .isSelected : [])
                    }
                }
                KokoField(label: "A little about you · optional, up to 180 characters", value: $introduction, multiline: true)
                KokoAction(title: importingPhoto ? "Preparing your photo…" : (isOnboarding ? (community.journal?.accountCredentialKind == "apple" ? "Enter Koko" : "Next") : "Save profile"), icon: 12, action: save)
                    .disabled(importingPhoto || journey.transitioning)
                if isOnboarding { KokoAction(title: "Use another account", emphasis: false) { community.signOut() } }
            }.disabled(showingCamera || choosingCountry || journey.transitioning)
            if choosingCountry {
                KokoModal(title: "Where feels like home?", dismiss: { choosingCountry = false }) {
                    KokoField(label: "Search country or region", value: $countryQuery)
                    if countryChoices.isEmpty { Text("No matching places. Try another name.").foregroundStyle(KokoInk.secondary) }
                    ForEach(countryChoices, id: \.self) { code in
                        Button { countryCode = code; choosingCountry = false } label: {
                            Text(Locale(identifier: "en").localizedString(forRegionCode: code) ?? code)
                                .font(.custom("AvenirNext-Medium", size: 15)).frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
                                .padding(.horizontal, 12).background(ArtworkSurface(tile: code == countryCode ? 3 : 5))
                        }.buttonStyle(KokoPressStyle())
                    }
                }
            }
            if showingCamera {
                KokoPortraitCameraPage(close: { showingCamera = false }) { jpeg in
                    portraitRevision = UUID(); selectedPhoto = nil; portraitJPEG = jpeg; usingArtwork = false; showingCamera = false
                }
            }
        }.onAppear(perform: loadDraft)
            .onChange(of: selectedPhoto) { selection in importPhoto(selection) }
            .onDisappear { portraitRevision = UUID() }
    }
    @ViewBuilder private var portrait: some View {
        if let jpeg = portraitJPEG, let image = UIImage(data: jpeg) { Image(uiImage: image).resizable().scaledToFit() }
        else if !usingArtwork, let draft { KokoMemberPortrait(member: draft) }
        else { Artwork(sheet: .collection, tile: portraitTile) }
    }
    private func loadDraft() {
        guard draft == nil, let member = community.currentMember else { return }
        draft = member; displayName = member.publicName; gender = member.genderLabel
        countryCode = member.homeCountryCode ?? ""; introduction = member.introductionLine
        chosenInterests = Set(member.interests); portraitTile = member.portraitTile
        usingArtwork = member.portraitFileName == nil
        if let birthday = member.birthday {
            let values = KokoAccountValidation.birthdayCalendar.dateComponents([.year, .month, .day], from: birthday)
            birthYear = String(values.year ?? 0); birthMonth = String(values.month ?? 0); birthDay = String(values.day ?? 0)
        }
    }
    private func importPhoto(_ selection: PhotosPickerItem?) {
        guard let selection else { return }
        let revision = UUID(); portraitRevision = revision; importingPhoto = true
        Task {
            do {
                guard let data = try await selection.loadTransferable(type: Data.self) else { throw KokoPortraitFiles.PortraitFailure.unreadable }
                let jpeg = try await Task.detached(priority: .userInitiated) { try KokoPortraitFiles.preparedJPEG(from: data) }.value
                guard portraitRevision == revision else { return }
                portraitJPEG = jpeg; usingArtwork = false; importingPhoto = false
            } catch {
                guard portraitRevision == revision else { return }
                importingPhoto = false; community.notice = "This photo couldn't be imported. Try another photo, or take a new one."
            }
        }
    }
    private func save() {
        guard !importingPhoto, var member = draft else { return }
        member.publicName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        member.genderLabel = gender; member.homeCountryCode = countryCode
        member.hometownLabel = countryName; member.introductionLine = introduction.trimmingCharacters(in: .whitespacesAndNewlines)
        member.interests = interestOptions.filter { chosenInterests.contains($0) }
        member.portraitTile = portraitTile
        if usingArtwork { member.portraitFileName = nil }
        guard let year = Int(birthYear), let month = Int(birthMonth), let day = Int(birthDay),
              (1900...2100).contains(year), (1...12).contains(month), (1...31).contains(day) else {
            community.notice = "Enter your full birthday using year, month and day."; return
        }
        let calendar = KokoAccountValidation.birthdayCalendar
        guard let birthday = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) else { return }
        let values = calendar.dateComponents([.year, .month, .day], from: birthday)
        guard values.year == year, values.month == month, values.day == day else { community.notice = "That date doesn't exist. Check the day, month and year."; return }
        member.birthday = birthday; member.adultAge = KokoAccountValidation.age(for: birthday)
        if let issue = KokoAccountValidation.profileIssue(member) { community.notice = issue; return }
        guard member.introductionLine.count <= 180 else { community.notice = "Keep your introduction within 180 characters."; return }
        let completedMember = member; let photo = portraitJPEG
        if isOnboarding {
            journey.enter(caption: "Your first hello is waiting.") { _ = community.saveProfile(completedMember, portraitJPEG: photo) }
        } else if community.saveProfile(member, portraitJPEG: photo) { onFinish?() }
    }
}
