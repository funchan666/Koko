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
    @Environment(\.dynamicTypeSize) private var textSize
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
    @State private var showingPhotoLibrary = false
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
        GeometryReader { viewport in
            let formWidth = max(0, min(viewport.size.width - 40, 460))
            ZStack {
                VStack(spacing: 0) {
                    editorNavigation.frame(width: formWidth)
                        .padding(.top, screenInsets.top + 8).padding(.bottom, 8)
                    ScrollViewReader { scroll in
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 22) {
                                editorHeading.id("profile-top")
                                if page == .basics { basicsFields } else { preferenceFields }
                            }
                            .frame(width: formWidth, alignment: .leading)
                            .padding(.top, 12).padding(.bottom, 22)
                            .frame(width: viewport.size.width)
                        }
                        .frame(width: viewport.size.width)
                        .scrollDismissesKeyboard(.interactively)
                        .onChange(of: page) { _ in scroll.scrollTo("profile-top", anchor: .top) }
                        .onChange(of: editing) { field in
                            if let field { scroll.scrollTo(field, anchor: .center) }
                        }
                    }
                    if !showingCamera && !choosingCountry && portraitPermissionHelp == nil {
                        editorFooter.frame(width: formWidth)
                            .padding(.top, 8)
                            .padding(.bottom, editing == nil ? screenInsets.bottom + 12 : 10)
                    }
                }
                // Art is a background only and cannot propose an oversized width.
                .frame(width: viewport.size.width, height: viewport.size.height)
                .background {
                    Image("KokoProfileEditorBackdrop").resizable().scaledToFill()
                        .frame(width: viewport.size.width, height: viewport.size.height)
                        .clipped().accessibilityHidden(true)
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
            }.frame(width: viewport.size.width, height: viewport.size.height)
        }
        .foregroundStyle(KokoWelcomePalette.paper)
        .tint(KokoWelcomePalette.mint)
        .onAppear { journey.usesDarkProfileAppearance = true; loadDraft() }
        .onChange(of: scenePhase) { phase in
            if phase == .background { portraitPermissionAttempt = UUID(); checkingPortraitPermission = false; portraitPermissionHelp = nil }
        }
        .onChange(of: selectedPhoto) { selection in importPhoto(selection) }
        .onDisappear { portraitRevision = UUID(); portraitPermissionAttempt = UUID(); checkingPortraitPermission = false; journey.usesDarkProfileAppearance = false }
    }

    private var editorNavigation: some View {
        HStack(spacing: 12) {
            backButton(action: goBack)
            Spacer(minLength: 0)
            Text(LocalizedStringKey(page == .basics ? "Step 1 of 2" : "Step 2 of 2"))
                .font(KokoTypography.emphasis(size: 12, relativeTo: .caption))
                .foregroundStyle(KokoWelcomePalette.mint)
        }.frame(minHeight: 44)
    }

    private var editorHeading: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(LocalizedStringKey(page == .basics ? (isOnboarding ? "Make it yours." : "Your profile") : "A little about you."))
                .font(KokoTypography.heading(size: 28, relativeTo: .title))
                .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
            Text(LocalizedStringKey(page == .basics ? "Your photo. Your name. Your kind of company." : "A few details to start with."))
                .font(KokoTypography.body(size: 13, relativeTo: .subheadline))
                .foregroundStyle(KokoWelcomePalette.quiet)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var editorFooter: some View {
        VStack(spacing: 6) {
            if editing != nil {
                HStack {
                    Spacer(minLength: 0)
                    Button { editing = nil } label: {
                        Text("Done").font(KokoTypography.emphasis(size: 13))
                            .foregroundStyle(KokoInk.accent).frame(minWidth: 60, minHeight: 44)
                    }.buttonStyle(KokoPressStyle())
                }
            }
            Button(action: advance) {
                Text(LocalizedStringKey(importingPhoto ? "Preparing photo…" : (page == .basics ? "Continue" : (isOnboarding ? "Enter Koko" : "Save profile"))))
                    .font(KokoTypography.heading(size: 16, relativeTo: .body))
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(KokoInk.canvas)
                    .padding(.horizontal, 20).padding(.vertical, 14)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(KokoProfileChoiceSurface(selected: true))
                    .contentShape(Rectangle())
            }.buttonStyle(KokoPressStyle()).disabled(importingPhoto || journey.transitioning)
        }
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
                portrait.frame(width: 116, height: 116).clipped()
                    .accessibilityLabel("Your profile photo")
                let layout = textSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 10))
                layout {
                    Button { showingPhotoLibrary = true } label: {
                        photoActionLabel("Choose photo", image: "KokoProfilePhotoLibrary")
                    }.buttonStyle(KokoPressStyle()).disabled(importingPhoto || checkingPortraitPermission)
                        .photosPicker(isPresented: $showingPhotoLibrary, selection: $selectedPhoto, matching: .images, photoLibrary: .shared())
                    Button(action: requestPortraitCamera) {
                        photoActionLabel("Take photo", image: "KokoProfilePortraitCamera")
                    }.buttonStyle(KokoPressStyle()).disabled(importingPhoto || checkingPortraitPermission)
                }
            }.frame(maxWidth: .infinity)
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

    private func photoActionLabel(_ title: String, image: String) -> some View {
        HStack(spacing: 8) {
            Image(image).resizable().scaledToFit().frame(width: 28, height: 28).accessibilityHidden(true)
            Text(LocalizedStringKey(title)).font(KokoTypography.emphasis(size: 12, relativeTo: .subheadline))
                .fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.leading)
        }.padding(.horizontal, 10).padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(KokoProfileChoiceSurface(selected: false))
            .contentShape(Rectangle())
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
                let birthdayLayout = textSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(alignment: .top, spacing: 10))
                birthdayLayout {
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
        KokoModal(title: "Country or region", presentation: .selection,
                  dismiss: { editing = nil; choosingCountry = false }) {
            profileField(.countrySearch, title: "Search", placeholder: "Find your country", value: $countryQuery)
            LazyVStack(spacing: 8) {
                if countryChoices.isEmpty {
                    Text("No matches. Try another name.")
                        .foregroundStyle(KokoWelcomePalette.quiet).padding(.vertical, 16)
                }
                ForEach(countryChoices, id: \.self) { code in
                    Button { countryCode = code; editing = nil; choosingCountry = false } label: {
                        controlLabel(interfaceLocale.localizedString(forRegionCode: code) ?? code,
                                     selected: code == countryCode)
                    }.buttonStyle(KokoPressStyle()).accessibilityAddTraits(code == countryCode ? .isSelected : [])
                }
            }
        }
    }

    private var choiceColumns: [GridItem] { Array(repeating: GridItem(.flexible(minimum: 0), spacing: 10), count: textSize.isAccessibilitySize ? 1 : 2) }
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
            Artwork(sheet: .navigation, tile: 5).frame(width: 25, height: 25)
                .frame(width: 44, height: 44).contentShape(Rectangle())
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
                .frame(minWidth: 0, maxWidth: .infinity)
                .padding(.horizontal, 16).padding(.vertical, 14).frame(minWidth: 0, maxWidth: .infinity, minHeight: multiline ? 96 : 52)
                .background(KokoProfileChoiceSurface(selected: false))
                .accessibilityLabel(Text(LocalizedStringKey(title)))
        }.frame(minWidth: 0, maxWidth: .infinity, alignment: .leading).id(field)
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

private struct KokoProfileChoiceSurface: View {
    @Environment(\.kokoDialogContent) private var inDialog
    var selected: Bool
    var body: some View {
        if inDialog {
            KokoDialogControlSurface(prominent: selected)
        } else {
            Image(selected ? "KokoProfileChoiceActive" : "KokoProfileFieldSurface")
                .resizable().accessibilityHidden(true)
        }
    }
}
