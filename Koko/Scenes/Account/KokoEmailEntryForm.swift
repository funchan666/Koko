import SwiftUI
import UIKit

private enum KokoEmailEntryField: Hashable {
    case email, password, confirmation
}

struct KokoEmailEntryForm: View {
    @Environment(\.kokoScreenInsets) private var screenInsets
    let registration: Bool
    @Binding var emailAddress: String
    @Binding var passwordDraft: String
    @Binding var repeatedPassword: String
    @Binding var agreed: Bool
    let back: () -> Void
    let switchMode: () -> Void
    let submit: () -> Void
    let openPolicy: (KokoLegalDocument) -> Void

    @FocusState private var editing: KokoEmailEntryField?
    @State private var attemptedContinue = false
    @State private var explainsLocalEntry = false
    @ScaledMetric(relativeTo: .largeTitle) private var headlineSize: CGFloat = 36
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        ScrollViewReader { scroll in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        editing = nil
                        back()
                    } label: {
                        Text("Back")
                            .font(.custom("AvenirNext-DemiBold", size: 14, relativeTo: .body))
                            .foregroundStyle(KokoWelcomePalette.mint)
                            .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                    }.buttonStyle(KokoPressStyle()).accessibilityLabel("Back to welcome")

                    HStack(alignment: .center, spacing: 12) {
                        Text(registration ? "Create\naccount." : "Welcome\nback.")
                            .font(.custom("AvenirNext-Bold", size: min(headlineSize, 58)))
                            .tracking(-1.2)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .layoutPriority(1)
                            .accessibilityAddTraits(.isHeader)
                        if !textSize.isAccessibilitySize {
                            Image("KokoWelcomeCompany").resizable().scaledToFit()
                                .frame(width: 104, height: 104).accessibilityHidden(true)
                        }
                    }.padding(.top, 12).padding(.bottom, 26)

                    VStack(spacing: 18) {
                        entryField(.email, title: "Email", placeholder: "you@example.com",
                                   value: $emailAddress, secure: false, contentType: .emailAddress)
                        entryField(.password, title: "Password", placeholder: "8–128 characters",
                                   value: $passwordDraft, secure: true,
                                   contentType: registration ? .newPassword : .password)
                        if registration {
                            entryField(.confirmation, title: "Confirm password", placeholder: "Enter it again",
                                       value: $repeatedPassword, secure: true, contentType: .newPassword)
                        }
                    }

                    KokoEntryAgreement(agreed: $agreed) { document in
                        editing = nil
                        openPolicy(document)
                    }.padding(.top, 20).padding(.bottom, 14)

                    KokoWelcomeAction(title: registration ? "Sign up" : "Start",
                                      primary: true, action: continueEntry)
                    Button {
                        editing = nil
                        switchMode()
                    } label: {
                        (Text(registration ? "Already here? " : "New here? ").foregroundColor(KokoWelcomePalette.quiet)
                         + Text(registration ? "Log in" : "Sign up").foregroundColor(KokoWelcomePalette.mint))
                            .font(.custom("AvenirNext-DemiBold", size: 14, relativeTo: .subheadline))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }.buttonStyle(KokoPressStyle()).padding(.top, 8)
                    Button {
                        editing = nil
                        explainsLocalEntry.toggle()
                    } label: {
                        Text(explainsLocalEntry ? "Hide sign-in details" : "How sign-in works")
                            .font(.custom("AvenirNext-Regular", size: 12, relativeTo: .caption))
                            .foregroundStyle(KokoWelcomePalette.quiet)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }.buttonStyle(KokoPressStyle())
                        .accessibilityValue(explainsLocalEntry ? "Expanded" : "Collapsed")
                    if explainsLocalEntry {
                        Text("This local preview checks email format and an 8–128 character password. No previous registration or matching password is needed to log in. The same email restores your saved profile on this device.")
                            .font(.custom("AvenirNext-Regular", size: 12, relativeTo: .caption))
                            .foregroundStyle(KokoWelcomePalette.quiet)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 28).padding(.top, screenInsets.top + 8)
                .padding(.bottom, editing == nil ? screenInsets.bottom + 24 : 24)
                .frame(maxWidth: 500).frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: editing) { field in
                guard let field else { return }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                    scroll.scrollTo(field, anchor: .center)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if editing != nil {
                HStack {
                    Spacer()
                    Button("Done") { editing = nil }
                        .font(.custom("AvenirNext-DemiBold", size: 14, relativeTo: .body))
                        .foregroundStyle(KokoWelcomePalette.mint)
                        .frame(minWidth: 60, minHeight: 44)
                        .buttonStyle(KokoPressStyle())
                }.padding(.horizontal, 20).background(KokoWelcomePalette.backdrop)
            }
        }
        .background(KokoWelcomePalette.backdrop.ignoresSafeArea())
        .foregroundStyle(KokoWelcomePalette.paper)
        .onDisappear { editing = nil }
    }

    private func entryField(_ field: KokoEmailEntryField, title: String, placeholder: String,
                            value: Binding<String>, secure: Bool, contentType: UITextContentType) -> some View {
        KokoEmailFormField(field: field, title: title, placeholder: placeholder,
                          value: value, secure: secure, contentType: contentType,
                          focusedField: $editing, issue: attemptedContinue ? issue(for: field) : nil,
                          finalField: field == (registration ? .confirmation : .password)) {
            switch field {
            case .email: editing = .password
            case .password where registration: editing = .confirmation
            default: continueEntry()
            }
        }.id(field)
    }

    private func issue(for field: KokoEmailEntryField) -> String? {
        switch field {
        case .email: return KokoAccountValidation.emailIssue(emailAddress)
        case .password: return KokoAccountValidation.passwordIssue(passwordDraft)
        case .confirmation:
            guard registration else { return nil }
            if repeatedPassword.isEmpty { return "Enter your password again." }
            return repeatedPassword == passwordDraft ? nil : "The passwords don't match."
        }
    }

    private func continueEntry() {
        // Consent remains explicit, and the account store repeats validation before saving.
        guard agreed else { editing = nil; submit(); return }
        attemptedContinue = true
        let required: [KokoEmailEntryField] = registration ? [.email, .password, .confirmation] : [.email, .password]
        if let invalid = required.first(where: { issue(for: $0) != nil }) {
            editing = invalid
            return
        }
        editing = nil
        submit()
    }
}

private struct KokoEmailFormField: View {
    let field: KokoEmailEntryField
    let title: String
    let placeholder: String
    @Binding var value: String
    let secure: Bool
    let contentType: UITextContentType
    let focusedField: FocusState<KokoEmailEntryField?>.Binding
    let issue: String?
    let finalField: Bool
    let advance: () -> Void
    @State private var revealsPassword = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.custom("AvenirNext-DemiBold", size: 12, relativeTo: .subheadline))
                .foregroundStyle(focusedField.wrappedValue == field ? KokoWelcomePalette.mint : KokoWelcomePalette.quiet)
            HStack(spacing: 8) {
                Group {
                    if secure && !revealsPassword {
                        SecureField(title, text: $value, prompt: Text(placeholder).foregroundColor(KokoWelcomePalette.quiet))
                    } else {
                        TextField(title, text: $value, prompt: Text(placeholder).foregroundColor(KokoWelcomePalette.quiet))
                    }
                }
                .textFieldStyle(.plain)
                .font(.custom("AvenirNext-Medium", size: 15, relativeTo: .body))
                .foregroundStyle(KokoWelcomePalette.paper)
                .tint(KokoWelcomePalette.mint)
                .keyboardType(field == .email ? .emailAddress : .asciiCapable)
                .textContentType(contentType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused(focusedField, equals: field)
                .submitLabel(finalField ? .go : .next)
                .onSubmit(advance)
                .accessibilityLabel(title)
                .accessibilityHint(issue ?? "")
                .padding(.vertical, 16)
                if secure {
                    Button {
                        revealsPassword.toggle()
                        focusedField.wrappedValue = field
                    } label: {
                        Text(revealsPassword ? "Hide" : "Show")
                            .font(.custom("AvenirNext-DemiBold", size: 12, relativeTo: .caption))
                            .foregroundStyle(KokoWelcomePalette.mint)
                            .frame(minWidth: 44, minHeight: 44)
                    }.buttonStyle(KokoPressStyle())
                        .accessibilityLabel(revealsPassword ? "Hide \(title.lowercased())" : "Show \(title.lowercased())")
                }
            }
            .padding(.horizontal, 16).frame(minHeight: 56)
            .background {
                Image("KokoAccountField").resizable().accessibilityHidden(true)
            }
            if let issue {
                Text(issue)
                    .font(.custom("AvenirNext-Medium", size: 12, relativeTo: .caption))
                    .foregroundStyle(Color(red: 0.97, green: 0.73, blue: 0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
