import Testing
@testable import Hibix

@Suite("ContactType")
struct ContactTypeTests {

    @Test
    func allCases_areTwoKinds() {
        #expect(ContactType.allCases == [.email, .line])
    }

    @Test
    func rawValues_areStableForDB() {
        #expect(ContactType.email.rawValue == "email")
        #expect(ContactType.line.rawValue == "line")
    }

    @Test
    func fromStoredValue_returnsValidCases() {
        #expect(ContactType.fromStoredValue("email") == .email)
        #expect(ContactType.fromStoredValue("line") == .line)
    }

    @Test
    func fromStoredValue_fallbacksToEmail_forUnknownOrNil() {
        #expect(ContactType.fromStoredValue(nil) == .email)
        #expect(ContactType.fromStoredValue("") == .email)
        #expect(ContactType.fromStoredValue("sms") == .email)
        // 廃止した phone は未知値として email にフォールバック (後方互換)
        #expect(ContactType.fromStoredValue("phone") == .email)
    }

    @Test
    func isDeliveredInV01_onlyEmailIsTrue() {
        #expect(ContactType.email.isDeliveredInV01 == true)
        #expect(ContactType.line.isDeliveredInV01 == false)
    }

    @Test
    func displayName_returnsJapaneseLabel() {
        #expect(ContactType.email.displayName == "メール")
        #expect(ContactType.line.displayName == "LINE")
    }
}
