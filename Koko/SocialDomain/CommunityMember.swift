import Foundation

struct CommunityMember: Identifiable, Codable, Hashable {
    var id: String
    var publicName: String
    var hometownLabel: String
    var spokenLanguage: String
    var adultAge: Int
    var genderLabel: String
    var introductionLine: String
    // Legacy artwork selection is retained for decoding existing journals only.
    var portraitTile: Int
    var interests: [String]
    var homeCountryCode: String? = nil
    var birthday: Date? = nil
    var portraitFileName: String? = nil
    var suppliedPortraitPhotoKey: String? = nil
    // Optional for compatibility with accounts saved before conversation cards existed.
    var conversationAnswers: [String: String]? = nil
}
