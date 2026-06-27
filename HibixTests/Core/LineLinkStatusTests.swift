import Testing
@testable import Hibix

@Suite("LineLinkStatus")
struct LineLinkStatusTests {
    @Test
    func fromStoredValue_knownValues() {
        #expect(LineLinkStatus.fromStoredValue("pending") == .pending)
        #expect(LineLinkStatus.fromStoredValue("linked") == .linked)
        #expect(LineLinkStatus.fromStoredValue("unlinked") == .unlinked)
    }

    @Test
    func fromStoredValue_unknownOrNil_fallsBackToUnlinked() {
        #expect(LineLinkStatus.fromStoredValue(nil) == .unlinked)
        #expect(LineLinkStatus.fromStoredValue("garbage") == .unlinked)
    }
}
