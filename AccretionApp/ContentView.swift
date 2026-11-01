//
//  ContentView.swift
//  AccretionApp
//
//  Created by Eric Freitas on 10/31/26.
//

import SwiftUI

/// A planet picked by clicking it in a row.
struct PlanetReference: Equatable {
    let systemID: StarSystem.ID
    let host: Int
    let index: Int
}

enum SystemSortOrder: String, CaseIterable, Identifiable {
    case generated = "Generated"
    case habitability = "Habitability"
    var id: Self { self }
}

struct ContentView: View {
    @State private var catalog = SystemCatalog()
    @State private var count = 10
    @State private var sortOrder = SystemSortOrder.generated
    @State private var selectedPlanet: PlanetReference?

    private let counts = [1, 10, 100, 1000]

    private var displayedSystems: [StarSystem] {
        sortOrder == .habitability ? catalog.systemsByHabitability : catalog.systems
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                    Section {
                        ForEach(displayedSystems) { system in
                            SystemRow(system: system,
                                      selectedPlanet: selectedPlanet?.systemID == system.id
                                          ? selectedPlanet : nil,
                                      onSelectPlanet: { host, index in
                                          selectedPlanet = PlanetReference(systemID: system.id,
                                                                           host: host, index: index)
                                      })
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
                    Text("\(catalog.habitableSystemCount) potentially habitable  ·  \(catalog.systems.count) systems in \(duration.formatted(.units(allowed: [.seconds, .milliseconds], width: .narrow)))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .fixedSize()
                        .layoutPriority(1)
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
                Picker("Sort", systemImage: "arrow.up.arrow.down", selection: $sortOrder) {
                    ForEach(SystemSortOrder.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu)
                .help("Sort systems")
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Generate", systemImage: "sparkles") {
                    selectedPlanet = nil
                    Task { await catalog.generate(count: count) }
                }
                .disabled(catalog.isGenerating)
                .keyboardShortcut("g")
            }
        }
        .inspector(isPresented: Binding(get: { selectedPlanet != nil },
                                        set: { if !$0 { selectedPlanet = nil } })) {
            ScrollView {
                if let reference = selectedPlanet,
                   let system = catalog.systems.first(where: { $0.id == reference.systemID }),
                   system.hosts.indices.contains(reference.host),
                   system.hosts[reference.host].planets.indices.contains(reference.index) {
                    let host = system.hosts[reference.host]
                    PlanetDetailView(planet: host.planets[reference.index],
                                     number: reference.index + 1, host: host, system: system,
                                     onClose: { selectedPlanet = nil })
                }
            }
            .inspectorColumnWidth(min: 280, ideal: 320, max: 420)
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
        HStack(spacing: 4) {
            Circle().strokeBorder(.green, lineWidth: 1.5).frame(width: 11, height: 11)
            Text("Potentially habitable")
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 1000, height: 600)
}
