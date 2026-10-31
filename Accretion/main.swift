//
//  main.swift
//  Accretion
//
//  Created by Eric Freitas on 10/31/26.
//
//  Usage: Accretion [-v] [-s <seed>] [-o <file>]
//    -v  print accretion progress (the original's VERBOSE output)
//    -s  seed, to regenerate a specific system
//    -o  output file (default: New.System in the current directory)
//

import Foundation

var verbose = false
var seed: UInt64?
var outputPath = "New.System"

var arguments = CommandLine.arguments.dropFirst().makeIterator()
while let arg = arguments.next() {
    switch arg {
    case "-v", "--verbose":
        verbose = true
    case "-s", "--seed":
        if let value = arguments.next(), let n = UInt64(value) { seed = n }
    case "-o", "--output":
        if let value = arguments.next() { outputPath = value }
    default:
        print("Ignoring unknown argument: \(arg)")
    }
}

let generator = StarSystemGenerator(seed: seed, verbose: verbose)
let system = generator.generate()
let report = system.report()
print(report)

let url = URL(fileURLWithPath: outputPath,
              relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
do {
    try report.write(to: url, atomically: true, encoding: .utf8)
    print("Wrote \(url.path)")
} catch {
    print("Could not write \(url.path): \(error.localizedDescription)")
}
