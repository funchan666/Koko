import SwiftUI
import PhotosUI
import AVFoundation

struct KokoProfileEditor: View {
    @EnvironmentObject private var community: CommunityJournalStore
    @EnvironmentObject private var journey: KokoAccessJourney
    let isOnboarding: Bool
    var onFinish: (() -> Void)? = nil
    @Environment(\.kokoScreenInsets) private var screenInsets
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var interfaceLocale
    @FocusState private var editing: KokoProfileField?
    @State private var page: KokoProfilePage = .basics
    @State private var draft: CommunityMember?
    @State private var displayName = ""
    @State private var gender = ""
    @State private var countryCode = ""
    @State private var birthYear = ""
    @State private var birthMonth = ""
    @State private var birthDay = ""
    @State private var introduction = ""
    @State private var chosenInterests: Set<String> = []
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var portraitJPEG: Data?
    @State private var importingPhoto = false
    @State private var showingCamera = false
    @State private var checkingPortraitPermission = false
    @State private var portraitPermissionHelp: KokoCapturePermission.Decision?
    @State private var portraitPermissionAttempt = UUID()
    @State private var choosingCountry = false
    @State private var countryQuery = ""
    @State private var portraitRevision = UUID()
    private let interestOptions = ["Music", "Conversation", "Creative", "After hours", "Travel", "Films", "Food", "Books"]
    private var countryName: String { interfaceLocale.localizedString(forRegionCode: countryCode) ?? "Choose country or region" }
    private var countryChoices: [String] {
        Locale.Region.isoRegions.map(\.identifier).filter { code in
            countryQuery.isEmpty || code.localizedCaseInsensitiveContains(countryQuery) || (interfaceLocale.localizedString(forRegionCode: code) ?? code).localizedCaseInsensitiveContains(countryQuery)
        }.sorted { (interfaceLocale.localizedString(forRegionCode: $0) ?? $0) < (interfaceLocale.localizedString(forRegionCode: $1) ?? $1) }
    }
    var body: some View {
        ZStack {
            ZStack(alignment: .topTrailing) {
                KokoGradientBackdrop()
                Image("KokoSocialAtlas")
                    .resizable().scaledToFit()
                    .frame(width: 250, height: 188)
                    .opacity(0.07)
                    .offset(x: 94, y: -14)
                    .accessibilityHidden(true)
            }
            ScrollViewReader { scroll in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack {
                            backButton(action: goBack)
                            Spacer()
                            Text(LocalizedStringKey(page == .basics ? "01 / 02" : "02 / 02"))
                                .font(KokoTypography.emphasis(size: 12, relativeTo: .caption))
                                .tracking(2).foregroundStyle(KokoWelcomePalette.mint)
                                .accessibilityLabel(Text(LocalizedStringKey(page == .basics ? "Step 1 of 2" : "Step 2 of 2")))
                        }.id("profile-top")
                        VStack(alignment: .leading, spacing: 6) {
                            Text(LocalizedStringKey(page == .basics ? "Make it yours." : "A little about you."))
                                .font(KokoTypography.heading(size: 32, relativeTo: .largeTitle))
                                .tracking(-1).accessibilityAddTraits(.isHeader)
                            Text(LocalizedStringKey(page == .basics ? "Your photo. Your name. Your kind of company." : "A few details to start with."))
                                .font(KokoTypography.body(size: 13, relativeTo: .subheadline))
                                .foregroundStyle(KokoWelcomePalette.quiet)
                        }.id("profile-heading")
                        if page == .basics { basicsFields } else { preferenceFields }
                        KokoWelcomeAction(title: importingPhoto ? "Preparing photo…" : (page == .basics ? "Continue" : (isOnboarding ? "Enter Koko" : "Save profile")),
                                          primary: true, action: advance)
                            .disabled(importingPhoto || journey.transitioning)
                    }
                    .padding(.horizontal, 26).padding(.top, screenInsets.top + 8)
                    .padding(.bottom, editing == nil ? screenInsets.bottom + 24 : 24)
                    .frame(maxWidth: 500).frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: page) { _ in scroll.scrollTo("profile-top", anchor: .top) }
                .onChange(of: editing) { field in
                    if let field { scroll.scrollTo(field, anchor: .center) }
                }
            }
            .disabled(showingCamera || choosingCountry || portraitPermissionHelp != nil || journey.transitioning)
            .accessibilityHidden(showingCamera || choosingCountry || portraitPermissionHelp != nil)
            if choosingCountry { countryPicker }
            if let permission = portraitPermissionHelp {
                KokoModal(title: "Camera unavailable", dismiss: { portraitPermissionHelp = nil }) {
                    Text(LocalizedStringKey(permission == .restricted ? "Camera access is restricted on this device." : "Camera access is unavailable. You can choose a photo instead or review access in Settings."))
                    if permission == .deniedPreviously { KokoDeviceSettingsAction() }
                    KokoAction(title: "Not now", emphasis: false) { portraitPermissionHelp = nil }
                }
            }
            if showingCamera {
                KokoPortraitCameraPage(close: { showingCamera = false }) { jpeg in
                    portraitRevision = UUID(); selectedPhoto = nil; portraitJPEG = jpeg; showingCamera = false
                }
            }
        }
        .foregroundStyle(KokoWelcomePalette.paper)
        .tint(KokoWelcomePalette.mint)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if editing != nil && !showingCamera {
                HStack {
                    Spacer()
                    Button { editing = nil } label: {
                        controlLabel("Done", selected: true).frame(width: 88)
                    }.buttonStyle(KokoPressStyle())
                }.padding(.horizontal, 24).padding(.vertical, 6).background(KokoWelcomePalette.backdrop)
            }
        }
        .onAppear { journey.usesDarkProfileAppearance = true; loadDraft() }
        .onChange(of: scenePhase) { phase in
            if phase == .background { portraitPermissionAttempt = UUID(); checkingPortraitPermission = false; portraitPermissionHelp = nil }
        }
        .onChange(of: selectedPhoto) { selection in importPhoto(selection) }
        .onDisappear { portraitRevision = UUID(); portraitPermissionAttempt = UUID(); checkingPortraitPermission = false; journey.usesDarkProfileAppearance = false }
    }

    private func requestPortraitCamera() {
        guard !checkingPortraitPermission else { return }
        editing = nil; portraitPermissionHelp = nil; checkingPortraitPermission = true
        let attempt = UUID(); portraitPermissionAttempt = attempt
        let accountID = community.myID
        Task {
            guard portraitPermissionAttempt == attempt, community.myID == accountID else { return }
            let decision = await KokoCapturePermission.cameraDecision()
            guard portraitPermissionAttempt == attempt, community.myID == accountID else { return }
            checkingPortraitPermission = false
            switch decision {
            case .allowed: showingCamera = true
            case .declinedNow: break
            case .deniedPreviously, .restricted: portraitPermissionHelp = decision
            }
        }
    }

    private var basicsFields: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(spacing: 14) {
                HStack(spacing: 22) {
                    portrait.frame(width: 100, height: 100).clipped()
                        .accessibilityLabel("Your profile photo")
                    VStack(spacing: 8) {
                        PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                            Text("Choose photo")
                                .font(KokoTypography.emphasis(size: 13, relativeTo: .body))
                                .foregroundStyle(KokoWelcomePalette.backdrop)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(KokoProfileChoiceSurface(selected: true))
                        }.buttonStyle(KokoPressStyle()).disabled(importingPhoto || checkingPortraitPermission)
                        Button { requestPortraitCamera() } label: { controlLabel("Take photo") }
                            .buttonStyle(KokoPressStyle()).disabled(importingPhoto || checkingPortraitPermission)
                    }
                }
            }
            profileField(.name, title: "Display name", placeholder: "What should we call you?", value: $displayName)
            VStack(alignment: .leading, spacing: 10) {
                fieldHeading("Gender")
                LazyVGrid(columns: choiceColumns, spacing: 10) {
                    ForEach(["Woman", "Man", "Non-binary", "Prefer not to say"], id: \.self) { option in
                        Button { gender = option; editing = nil } label: {
                            controlLabel(option, selected: gender == option)
                        }.buttonStyle(KokoPressStyle()).accessibilityAddTraits(gender == option ? .isSelected : [])
                    }
                }
            }
        }
    }

    private var preferenceFields: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                fieldHeading("Country or region")
                Button { editing = nil; countryQuery = ""; choosingCountry = true } label: {
                    HStack(spacing: 12) {
                        Text(LocalizedStringKey(countryCode.isEmpty ? "Choose your country" : countryName))
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        Text("Change").font(KokoTypography.emphasis(size: 12, relativeTo: .caption))
                            .foregroundStyle(KokoWelcomePalette.mint)
                    }
                    .font(KokoTypography.medium(size: 14, relativeTo: .body))
                    .padding(.horizontal, 16).padding(.vertical, 14).frame(minHeight: 54)
                    .background(KokoProfileChoiceSurface(selected: false))
                }.buttonStyle(KokoPressStyle())
            }
            VStack(alignment: .leading, spacing: 8) {
                fieldHeading("Birthday")
                HStack(alignment: .top, spacing: 10) {
                    profileField(.year, title: "Year", placeholder: "YYYY", value: $birthYear, numeric: true)
                    profileField(.month, title: "Month", placeholder: "MM", value: $birthMonth, numeric: true)
                    profileField(.day, title: "Day", placeholder: "DD", value: $birthDay, numeric: true)
                }
                Text("18+ only. Your full birthday stays private.")
                    .font(KokoTypography.body(size: 11, relativeTo: .caption))
                    .foregroundStyle(KokoWelcomePalette.quiet)
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    fieldHeading("Into anything good?")
                    Spacer()
                    Text("Pick at least one").font(KokoTypography.body(size: 11, relativeTo: .caption))
                        .foregroundStyle(KokoWelcomePalette.quiet)
                }
                LazyVGrid(columns: choiceColumns, spacing: 10) {
                    ForEach(interestOptions, id: \.self) { interest in
                        Button {
                            editing = nil
                            if chosenInterests.contains(interest) { chosenInterests.remove(interest) } else { chosenInterests.insert(interest) }
                        } label: { controlLabel(interest, selected: chosenInterests.contains(interest)) }
                            .buttonStyle(KokoPressStyle())
                            .accessibilityAddTraits(chosenInterests.contains(interest) ? .isSelected : [])
                    }
                }
            }
            profileField(.introduction, title: "About you · optional", placeholder: "A little something to say hello…", value: $introduction, multiline: true)
            Text("\(introduction.count) / 180")
                .font(KokoTypography.body(size: 11, relativeTo: .caption))
                .foregroundStyle(KokoWelcomePalette.quiet).frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, -16)
        }
    }

    private var countryPicker: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                backButton { editing = nil; choosingCountry = false }
                Text("Country or region").font(KokoTypography.heading(size: 22, relativeTo: .title2))
                Spacer(minLength: 0)
            }
            profileField(.countrySearch, title: "Search", placeholder: "Find your country", value: $countryQuery)
            ScrollView {
                LazyVStack(spacing: 8) {
                    if countryChoices.isEmpty {
                        Text("No matches. Try another name.")
                            .foregroundStyle(KokoWelcomePalette.quiet).padding(.vertical, 24)
                    }
                    ForEach(countryChoices, id: \.self) { code in
                        Button { countryCode = code; editing = nil; choosingCountry = false } label: {
                            controlLabel(interfaceLocale.localizedString(forRegionCode: code) ?? code,
                                         selected: code == countryCode)
                        }.buttonStyle(KokoPressStyle()).accessibilityAddTraits(code == countryCode ? .isSelected : [])
                    }
                }.padding(.bottom, screenInsets.bottom + 16)
            }.scrollDismissesKeyboard(.interactively)
        }
        .padding(.horizontal, 26).padding(.top, screenInsets.top + 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KokoWelcomePalette.backdrop)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { editing = nil; choosingCountry = false }
    }

    private var choiceColumns: [GridItem] { [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)] }
    private func fieldHeading(_ title: String) -> some View {
        Text(LocalizedStringKey(title)).font(KokoTypography.emphasis(size: 12, relativeTo: .subheadline))
            .foregroundStyle(KokoWelcomePalette.quiet)
    }
    private func controlLabel(_ title: String, selected: Bool = false) -> some View {
        Text(LocalizedStringKey(title)).font(KokoTypography.emphasis(size: 13, relativeTo: .body))
            .foregroundStyle(selected ? KokoWelcomePalette.backdrop : KokoWelcomePalette.paper)
            .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12).padding(.vertical, 12).frame(maxWidth: .infinity, minHeight: 48)
            .background(KokoProfileChoiceSurface(selected: selected))
    }
    private func backButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image("KokoAccountBack").resizable().scaledToFit().frame(width: 44, height: 44).accessibilityHidden(true)
        }.buttonStyle(KokoPressStyle()).accessibilityLabel("Back")
    }
    private func profileField(_ field: KokoProfileField, title: String, placeholder: String,
                              value: Binding<String>, numeric: Bool = false, multiline: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldHeading(title)
            TextField(title, text: value, prompt: Text(LocalizedStringKey(placeholder)).foregroundColor(KokoWelcomePalette.quiet), axis: multiline ? .vertical : .horizontal)
                .textFieldStyle(.plain)
                .font(KokoTypography.medium(size: 15, relativeTo: .body))
                .foregroundStyle(KokoWelcomePalette.paper).tint(KokoWelcomePalette.mint)
                .keyboardType(numeric ? .numberPad : .default)
                .textInputAutocapitalization(field == .name ? .words : .sentences)
                .autocorrectionDisabled(numeric)
                .focused($editing, equals: field)
                .submitLabel(.done).onSubmit { editing = nil }
                .padding(.horizontal, 14).padding(.vertical, 16).frame(minHeight: 54)
                .background(KokoProfileChoiceSurface(selected: false))
                .accessibilityLabel(Text(LocalizedStringKey(title)))
        }.id(field)
    }
    private func goBack() {
        editing = nil
        if page == .preferences { page = .basics }
        else if isOnboarding { community.signOut() }
        else { onFinish?() }
    }
    private func advance() {
        editing = nil
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (2...40).contains(name.count) else {
            page = .basics; community.notice = "Choose a name between 2 and 40 characters."; return
        }
        guard !gender.isEmpty else {
            page = .basics; community.notice = "Choose a gender option, or select Prefer not to say."; return
        }
        if page == .basics { page = .preferences } else { save() }
    }
    @ViewBuilder private var portrait: some View {
        if let jpeg = portraitJPEG, let image = UIImage(data: jpeg) { KokoPortraitPhoto(image: image) }
        else if let draft { KokoMemberPortrait(member: draft) }
        else { KokoPhotoPlaceholder() }
    }
    private func loadDraft() {
        guard draft == nil, let member = community.currentMember else { return }
        draft = member; displayName = member.publicName; gender = member.genderLabel
        countryCode = member.homeCountryCode ?? ""; introduction = member.introductionLine
        chosenInterests = Set(member.interests)
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
                portraitJPEG = jpeg; importingPhoto = false
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
        member.hometownLabel = Locale(identifier: "en").localizedString(forRegionCode: countryCode) ?? countryCode; member.introductionLine = introduction.trimmingCharacters(in: .whitespacesAndNewlines)
        member.interests = interestOptions.filter { chosenInterests.contains($0) }
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
            journey.enter(caption: "Saving your profile…") { _ = community.saveProfile(completedMember, portraitJPEG: photo) }
        } else if community.saveProfile(member, portraitJPEG: photo) { onFinish?() }
    }
}


private enum KokoProfilePage: Equatable { case basics, preferences }
private enum KokoProfileField: Hashable { case name, year, month, day, introduction, countrySearch }

@MainActor
private enum KokoProfileSelectionArtwork {
    private static var prepared: [Bool: UIImage] = [:]
    static func skin(selected: Bool) -> UIImage {
        if let cached = prepared[selected] { return cached }
        guard let source = UIImage(named: "KokoProfileSelection")?.cgImage else { return UIImage() }
        let scale = CGFloat(source.width) / 1254
        let bounds = CGRect(x: 62 * scale, y: (selected ? 668 : 272) * scale, width: 1130 * scale, height: 338 * scale)
        guard let crop = source.cropping(to: bounds) else { return UIImage() }
        let image = UIImage(cgImage: crop, scale: 6 * scale, orientation: .up)
        prepared[selected] = image
        return image
    }
}

private struct KokoProfileChoiceSurface: View {
    var selected: Bool
    var body: some View {
        Image(uiImage: KokoProfileSelectionArtwork.skin(selected: selected))
            .resizable(capInsets: EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18), resizingMode: .stretch)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(selected ? KokoWelcomePalette.mint.opacity(0.85) : Color.white.opacity(0.16), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.16), radius: 10, y: 5)
            .accessibilityHidden(true)
    }
}
