import Testing
@testable import Hibix

@Suite("EmergencyContactEditViewModel.isValid")
struct EmergencyContactValidationTests {

    @Test
    func email_acceptsStandardAddress() {
        #expect(EmergencyContactEditViewModel.isValid(contactType: .email, value: "user@example.com"))
        #expect(EmergencyContactEditViewModel.isValid(contactType: .email, value: "a.b+c@example.jp"))
    }

    @Test
    func email_rejectsInvalidAddress() {
        #expect(EmergencyContactEditViewModel.isValid(contactType: .email, value: "") == false)
        #expect(EmergencyContactEditViewModel.isValid(contactType: .email, value: "no-at") == false)
        #expect(EmergencyContactEditViewModel.isValid(contactType: .email, value: "@example.com") == false)
        #expect(EmergencyContactEditViewModel.isValid(contactType: .email, value: "user@example") == false)
    }

    @Test
    func line_acceptsAnyNonEmptyValue() {
        #expect(EmergencyContactEditViewModel.isValid(contactType: .line, value: "@friend_id"))
        #expect(EmergencyContactEditViewModel.isValid(contactType: .line, value: "https://line.me/ti/p/abc"))
    }

    @Test
    func line_rejectsEmpty() {
        #expect(EmergencyContactEditViewModel.isValid(contactType: .line, value: "") == false)
    }

    @Test
    func phone_acceptsCommonFormats() {
        #expect(EmergencyContactEditViewModel.isValid(contactType: .phone, value: "090-1234-5678"))
        #expect(EmergencyContactEditViewModel.isValid(contactType: .phone, value: "+81 90 1234 5678"))
        #expect(EmergencyContactEditViewModel.isValid(contactType: .phone, value: "(03)1234-5678"))
    }

    @Test
    func phone_rejectsLettersOrEmpty() {
        #expect(EmergencyContactEditViewModel.isValid(contactType: .phone, value: "") == false)
        #expect(EmergencyContactEditViewModel.isValid(contactType: .phone, value: "abc-1234") == false)
        // 数字 5 文字未満は拒否
        #expect(EmergencyContactEditViewModel.isValid(contactType: .phone, value: "1234") == false)
    }
}
