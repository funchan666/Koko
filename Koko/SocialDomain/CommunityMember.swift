import Foundation

struct CommunityMember: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var publicName: String
    var hometownLabel: String
    var spokenLanguage: String
    var adultAge: Int
    var genderLabel: String
    var introductionLine: String
    var portraitTile: Int
    var interests: [String]
    var homeCountryCode: String? = nil
    var birthday: Date? = nil
    var portraitFileName: String? = nil
    var suppliedPortraitPhotoKey: String? = nil
    var conversationAnswers: [String: String]? = nil
}
