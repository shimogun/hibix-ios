import Testing
@testable import Hibix

@Suite("MoodLevel")
struct MoodLevelTests {

    @Test
    func fromStoredValue_returnsNewCases_forValidRawValues() {
        #expect(MoodLevel.fromStoredValue(1) == .down)
        #expect(MoodLevel.fromStoredValue(3) == .calm)
        #expect(MoodLevel.fromStoredValue(4) == .neutral)
        #expect(MoodLevel.fromStoredValue(5) == .good)
        #expect(MoodLevel.fromStoredValue(7) == .best)
    }

    @Test
    func fromStoredValue_migratesLegacySink_toDown() {
        #expect(MoodLevel.fromStoredValue(2) == .down)
    }

    @Test
    func fromStoredValue_migratesLegacyUplift_toGood() {
        #expect(MoodLevel.fromStoredValue(6) == .good)
    }

    @Test
    func fromStoredValue_returnsNil_forOutOfRange() {
        #expect(MoodLevel.fromStoredValue(0) == nil)
        #expect(MoodLevel.fromStoredValue(8) == nil)
        #expect(MoodLevel.fromStoredValue(-1) == nil)
    }

    @Test
    func allCases_areFiveLevels_inAscendingOrder() {
        let cases = MoodLevel.allCases
        #expect(cases.count == 5)
        #expect(cases == [.down, .calm, .neutral, .good, .best])
    }

    @Test
    func displayName_returnsJapaneseLabels() {
        #expect(MoodLevel.down.displayName == "落ち込み")
        #expect(MoodLevel.calm.displayName == "平静")
        #expect(MoodLevel.neutral.displayName == "普通")
        #expect(MoodLevel.good.displayName == "良い")
        #expect(MoodLevel.best.displayName == "最高")
    }

    @Test
    func iconAssetName_matchesBrandGuidelineMapping() {
        #expect(MoodLevel.down.iconAssetName == "mood-down")
        #expect(MoodLevel.calm.iconAssetName == "mood-calm")
        #expect(MoodLevel.neutral.iconAssetName == "mood-neutral")
        #expect(MoodLevel.good.iconAssetName == "mood-good")
        #expect(MoodLevel.best.iconAssetName == "mood-best")
    }
}
