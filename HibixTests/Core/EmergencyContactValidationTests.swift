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
}
