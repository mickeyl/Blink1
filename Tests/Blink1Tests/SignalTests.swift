import Testing
import Foundation
@testable import Blink1

@Suite("Signal bank")
struct SignalTests {

    @Test("gives every slot to exactly one signal")
    func layoutIsAPartition() {
        var owner: [Blink1.Signal?] = Array(repeating: nil, count: Blink1.Signal.requiredSlots)
        for signal in Blink1.Signal.allCases {
            for slot in signal.slots {
                #expect(Int(slot) < Blink1.Signal.requiredSlots)
                #expect(owner[Int(slot)] == nil, "slot \(slot) claimed twice")
                owner[Int(slot)] = signal
            }
        }
        #expect(owner.allSatisfy { $0 != nil }, "the bank leaves slots unused")
    }

    @Test("keeps every signal playable")
    func noSignalEndsAtSlotZero() {
        // the firmware reads an end position of 0 as "play the whole pattern"
        #expect(Blink1.Signal.allCases.allSatisfy { $0.slots.upperBound != 0 })
    }

    @Test("writes one step per slot", arguments: Blink1.Signal.allCases)
    func stepCountMatchesSlots(signal: Blink1.Signal) {
        #expect(signal.steps().count == signal.slots.count)
    }

    @Test("keeps every step visible", arguments: Blink1.Signal.allCases)
    func stepsLastLongEnoughToBeSeen(signal: Blink1.Signal) {
        // a step's fade time is also its duration, so a zero-length step would never be shown
        #expect(signal.steps().allSatisfy { $0.fadeDuration.blink1Milliseconds >= 50 })
    }

    @Test("scales with brightness")
    func scalesWithBrightness() {
        let full = Blink1.Signal.ok.steps(brightness: 1).first!.color
        let half = Blink1.Signal.ok.steps(brightness: 0.5).first!.color
        #expect(half.green == full.green / 2)
        #expect(Blink1.Signal.ok.steps(brightness: 0).first!.color == .black)
    }

    @Test("ends the one-shot signals on a color that stays", arguments: [Blink1.Signal.success, .failure])
    func oneShotSignalsEndLit(signal: Blink1.Signal) {
        #expect(signal.repeats == 1)
        #expect(signal.steps().last?.color.isBlack == false)
    }
}
