import Foundation

struct KokoPolicyConsent: Codable, Sendable {
    static let currentRevision = "2026-10-08"
    static let termsURL = URL(string: "https://sites.google.com/view/koko-terms-of-service/about")!
    static let privacyURL = URL(string: "https://sites.google.com/view/koko-privacypolicy/about")!
    var revision = KokoPolicyConsent.currentRevision
    var acceptedAt = Date()
    var termsAddress = KokoPolicyConsent.termsURL.absoluteString
    var privacyAddress = KokoPolicyConsent.privacyURL.absoluteString
}

enum KokoLegalDocument: String, Identifiable {
    case terms, privacy
    var id: String { rawValue }
    var title: String { self == .terms ? "Terms of Service" : "Privacy Policy" }
    var url: URL { self == .terms ? KokoPolicyConsent.termsURL : KokoPolicyConsent.privacyURL }
}

enum KokoAccountValidation {
    // Store a birthday as a calendar date, independent of the device's current time zone.
    static var birthdayCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
    static func age(for birthday: Date) -> Int {
        let birth = birthdayCalendar.dateComponents([.year, .month, .day], from: birthday)
        let today = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: Date())
        let anniversaryPassed = (today.month ?? 0) > (birth.month ?? 0) || ((today.month ?? 0) == (birth.month ?? 0) && (today.day ?? 0) >= (birth.day ?? 0))
        return (today.year ?? 0) - (birth.year ?? 0) - (anniversaryPassed ? 0 : 1)
    }
    static func normalizedEmail(_ email: String) -> String { email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
    static func emailIssue(_ email: String) -> String? {
        let address = normalizedEmail(email)
        guard !address.isEmpty else { return "Enter your email address first." }
        guard address.count <= 254, address.range(of: #"^[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}$"#, options: .caseInsensitive) != nil else { return "Enter a complete email address, such as name@example.com." }
        return nil
    }
    static func passwordIssue(_ password: String) -> String? {
        guard !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "Enter your password first." }
        return (8...128).contains(password.count) ? nil : "Use a password between 8 and 128 characters."
    }
    static func profileIssue(_ member: CommunityMember) -> String? {
        let name = member.publicName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (2...40).contains(name.count) else { return "Choose a display name between 2 and 40 characters." }
        guard ["Woman", "Man", "Non-binary", "Prefer not to say"].contains(member.genderLabel) else { return "Choose how you describe yourself, or select Prefer not to say." }
        guard let country = member.homeCountryCode, Locale.isoRegionCodes.contains(country) else { return "Choose your country or region." }
        guard let birthday = member.birthday else { return "Enter your date of birth." }
        guard (18...99).contains(age(for: birthday)) else { return "Koko is for adults aged 18 and over. Check your date of birth." }
        guard !member.interests.isEmpty else { return "Choose at least one interest so your space feels like you." }
        return nil
    }
}
