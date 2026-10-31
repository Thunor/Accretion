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
    private(set) var isGenerating = false
    private(set) var lastDuration: Duration?

    func generate(count: Int) async {
        isGenerating = true
        let clock = ContinuousClock()
        let start = clock.now
        systems = await Self.makeSystems(count: count)
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
