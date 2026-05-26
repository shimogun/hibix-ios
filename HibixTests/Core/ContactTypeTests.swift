import Testing
@testable import Hibix

@Suite("ContactType")
struct ContactTypeTests {

    @Test
    func allCases_areThreeKinds() {
        #expect(ContactType.allCases == [.email, .line, .phone])
    }

    @Test
    func rawValues_areStableForDB() {
        #expect(ContactType.email.rawValue == "email")
        #expect(ContactType.line.rawValue == "line")
        #expect(ContactType.phone.rawValue == "phone")
    }

    @Test
    func fromStoredValue_returnsValidCases() {
        #expect(ContactType.fromStoredValue("email") == .email)
        #expect(ContactType.fromStoredValue("line") == .line)
        #expect(ContactType.fromStoredValue("phone") == .phone)
    }

    @Test
    func fromStoredValue_fallbacksToEmail_forUnknownOrNil() {
        #expect(ContactType.fromStoredValue(nil) == .email)
        #expect(ContactType.fromStoredValue("") == .email)
        #expect(ContactType.fromStoredValue("sms") == .email)
    }

    @Test
    func isDeliveredInV01_onlyEmailIsTrue() {
        #expect(ContactType.email.isDeliveredInV01 == true)
        #expect(ContactType.line.isDeliveredInV01 == false)
        #expect(ContactType.phone.isDeliveredInV01 == false)
    }

    @Test
    func displayName_returnsJapaneseLabel() {
        #expect(ContactType.email.displayName == "メール")
        #expect(ContactType.line.displayName == "LINE")
        #expect(ContactType.phone.displayName == "電話")
    }
}
