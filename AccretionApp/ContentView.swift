//
//  ContentView.swift
//  AccretionApp
//
//  Created by Eric Freitas on 10/31/26.
//

import SwiftUI

struct ContentView: View {
    @State private var catalog = SystemCatalog()
    @State private var count = 10

    private let counts = [1, 10, 100, 1000]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                    Section {
                        ForEach(catalog.systems) { system in
                            SystemRow(system: system)
                            Divider().opacity(0.4)
                        }
                    } header: {
                        OrbitAxis()
                            .background(.bar)
                    }
                }
            }
            .background(Color(red: 0.04, green: 0.04, blue: 0.08))
            .overlay {
                if catalog.isGenerating {
                    ProgressView("Generating \(count) systems…")
                        .padding()
                        .background(.regularMaterial, in: .rect(cornerRadius: 10))
                }
            }

            Divider()
            HStack {
                LegendView()
                Spacer()
                if let duration = catalog.lastDuration {
                    Text("\(catalog.systems.count) systems in \(duration.formatted(.units(allowed: [.seconds, .milliseconds], width: .narrow)))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
                .padding(.vertical, 8)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Systems", selection: $count) {
                    ForEach(counts, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Generate", systemImage: "sparkles") {
                    Task { await catalog.generate(count: count) }
                }
                .disabled(catalog.isGenerating)
                .keyboardShortcut("g")
            }
        }
        .navigationTitle("Accretion")
        .preferredColorScheme(.dark)
        .task { await catalog.generate(count: count) }
    }
}

/// Key for planet colors and the habitable zone line.
struct LegendView: View {
    var body: some View {
        ViewThatFits {
            // Fixed size so labels never truncate; scrolls instead when too narrow.
            HStack(spacing: 14) { items }.fixedSize()
            ScrollView(.horizontal) { HStack(spacing: 14) { items }.fixedSize() }
        }
        .font(.caption)
    }

    @ViewBuilder private var items: some View {
        HStack(spacing: 6) {
            ForEach(SpectralClass.allCases, id: \.self) { spectralClass in
                HStack(spacing: 2) {
                    Circle().fill(spectralClass.color).frame(width: 9, height: 9)
                    Text(spectralClass.rawValue)
                }
            }
        }
        Divider().frame(height: 12)
        ForEach(PlanetKind.allCases, id: \.self) { kind in
            HStack(spacing: 4) {
                Circle().fill(kind.color).frame(width: 9, height: 9)
                Text(kind.name)
            }
        }
        HStack(spacing: 4) {
            Capsule().fill(.green).frame(width: 18, height: 3)
            Text("Habitable zone")
        }
        HStack(spacing: 4) {
            Rectangle().fill(.orange).frame(width: 1.5, height: 12)
            Text("Stability limit")
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 1000, height: 600)
}
