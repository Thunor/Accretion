//
//  SystemCatalog.swift
//  AccretionApp
//

import Foundation
import Observation

/// Generates batches of star systems off the main actor.
@MainActor
@Observable
final class SystemCatalog {
    private(set) var systems: [StarSystem] = []
    /// The same systems, most habitable first (see `HabitabilityCandidate.score`).
    private(set) var systemsByHabitability: [StarSystem] = []
    private(set) var habitableSystemCount = 0
    private(set) var isGenerating = false
    private(set) var lastDuration: Duration?

    func generate(count: Int) async {
        isGenerating = true
        let clock = ContinuousClock()
        let start = clock.now
        let generated = await Self.makeSystems(count: count)
        let scores = generated.map { $0.bestHabitabilityCandidate?.score ?? -1 }
        systems = generated
        systemsByHabitability = zip(generated, scores).sorted { $0.1 > $1.1 }.map(\.0)
        habitableSystemCount = scores.filter { $0 >= 1 }.count
        lastDuration = start.duration(to: clock.now)
        isGenerating = false
    }

    /// Each system has its own generator and RNG, so they can be built in parallel.
    @concurrent
    private nonisolated static func makeSystems(count: Int) async -> [StarSystem] {
        await withTaskGroup(of: (Int, StarSystem).self) { group in
            for index in 0..<count {
                group.addTask { (index, StarSystemGenerator().generate()) }
            }
            var results = [StarSystem?](repeating: nil, count: count)
            for await (index, system) in group {
                results[index] = system
            }
            return results.compactMap { $0 }
        }
    }
}
