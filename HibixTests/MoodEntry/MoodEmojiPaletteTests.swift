import Testing
@testable import Hibix

@Suite("MoodEmojiPalette")
struct MoodEmojiPaletteTests {

    @Test
    func returnsSixEmojis_forEachMood() {
        for level in MoodLevel.allCases {
            let emojis = MoodEmojiPalette.emojis(for: level)
            #expect(emojis.count == 6, "MoodLevel \(level) should have 6 emojis")
        }
    }

    @Test
    func returnsDistinctSets_forDifferentMoods() {
        let downSet = Set(MoodEmojiPalette.emojis(for: .down))
        let bestSet = Set(MoodEmojiPalette.emojis(for: .best))
        let intersection = downSet.intersection(bestSet)
        #expect(intersection.isEmpty, "down と best は絵文字が被ってはならない")
    }
}
