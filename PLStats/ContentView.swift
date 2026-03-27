//
//  ContentView.swift
//  PLStats
//
//  Created by Hugo Padilla on 3/25/26.
//


import SwiftUI

// MARK: - Models

struct StandingsResponse: Codable {
    let standings: [StandingGroup]
}

struct StandingGroup: Codable {
    let type: String
    let table: [TableEntry]
}

struct TableEntry: Codable, Identifiable {
    var id: Int { position }
    let position: Int
    let team: Team
    let playedGames: Int
    let won: Int
    let draw: Int
    let lost: Int
    let points: Int
    let goalDifference: Int
    let goalsFor: Int
    let goalsAgainst: Int
    let form: String?
}

struct Team: Codable {
    let id: Int
    let name: String
    let shortName: String
    let tla: String
    let crest: String
}

struct FixturesResponse: Codable {
    let matches: [Match]
}

struct Match: Codable, Identifiable {
    let id: Int
    let utcDate: String
    let status: String
    let matchday: Int?
    let homeTeam: MatchTeam
    let awayTeam: MatchTeam
    let score: Score
}

struct MatchTeam: Codable {
    let id: Int?
    let name: String?
    let shortName: String?
    let crest: String?
}

struct Score: Codable {
    let winner: String?
    let fullTime: HalfScore
    let halfTime: HalfScore
}

struct HalfScore: Codable {
    let home: Int?
    let away: Int?
}

struct ScorersResponse: Codable {
    let scorers: [Scorer]
}

struct Scorer: Codable, Identifiable {
    var id: Int { player.id }
    let player: Player
    let team: Team
    let goals: Int
    let assists: Int?
    let penalties: Int?
    let playedMatches: Int?
}

struct Player: Codable {
    let id: Int
    let name: String
    let nationality: String?
    let position: String?
    let dateOfBirth: String?
}

struct TeamMatchesResponse: Codable {
    let matches: [Match]
}

// MARK: - Helpers

func isFinished(_ status: String) -> Bool { status == "FINISHED" }
func isUpcoming(_ status: String) -> Bool { ["SCHEDULED", "TIMED", "POSTPONED"].contains(status) }

func formattedMatchTime(_ utcDate: String) -> String {
    let iso = ISO8601DateFormatter()
    guard let date = iso.date(from: utcDate) else { return "" }
    let df = DateFormatter(); df.timeStyle = .short; df.timeZone = .current
    return df.string(from: date)
}

func formattedMatchDate(_ utcDate: String) -> String {
    let iso = ISO8601DateFormatter()
    guard let date = iso.date(from: utcDate) else { return utcDate }
    let df = DateFormatter(); df.dateStyle = .full; df.timeStyle = .short; df.timeZone = .current
    return df.string(from: date)
}

// MARK: - ViewModel

@Observable
class PLViewModel {
    var standings: [TableEntry] = []
    var fixtures: [Match] = []
    var scorers: [Scorer] = []
    var assisters: [Scorer] = []
    var teamMatches: [Int: [Match]] = [:]

    var loadingStandings = false
    var loadingFixtures = false
    var loadingScorers = false
    var loadingAssisters = false

    var standingsError: String?
    var fixturesError: String?
    var scorersError: String?
    var assistersError: String?

    var searchText = ""

    var filteredStandings: [TableEntry] {
        if searchText.isEmpty { return standings }
        return standings.filter {
            $0.team.name.localizedCaseInsensitiveContains(searchText) ||
            $0.team.shortName.localizedCaseInsensitiveContains(searchText) ||
            $0.team.tla.localizedCaseInsensitiveContains(searchText)
        }
    }

    private let apiKey = "657838a96b734b69bcc55ec05be2d0f5"

    func fetchStandings() async {
        loadingStandings = true; standingsError = nil
        defer { loadingStandings = false }
        guard let url = URL(string: "https://api.football-data.org/v4/competitions/PL/standings") else { return }
        var req = URLRequest(url: url); req.setValue(apiKey, forHTTPHeaderField: "X-Auth-Token")
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let decoded = try JSONDecoder().decode(StandingsResponse.self, from: data)
            if let total = decoded.standings.first(where: { $0.type == "TOTAL" }) { standings = total.table }
        } catch { standingsError = "Failed to load standings." }
    }

    func fetchFixtures() async {
        loadingFixtures = true; fixturesError = nil
        defer { loadingFixtures = false }
        guard let url = URL(string: "https://api.football-data.org/v4/competitions/PL/matches?limit=30") else { return }
        var req = URLRequest(url: url); req.setValue(apiKey, forHTTPHeaderField: "X-Auth-Token")
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let decoded = try JSONDecoder().decode(FixturesResponse.self, from: data)
            fixtures = decoded.matches.reversed()
        } catch { fixturesError = "Failed to load fixtures." }
    }

    func fetchScorers() async {
        loadingScorers = true; scorersError = nil
        defer { loadingScorers = false }
        guard let url = URL(string: "https://api.football-data.org/v4/competitions/PL/scorers?limit=20") else { return }
        var req = URLRequest(url: url); req.setValue(apiKey, forHTTPHeaderField: "X-Auth-Token")
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            scorers = try JSONDecoder().decode(ScorersResponse.self, from: data).scorers
        } catch { scorersError = "Failed to load scorers." }
    }

    func fetchAssisters() async {
        loadingAssisters = true; assistersError = nil
        defer { loadingAssisters = false }
        guard let url = URL(string: "https://api.football-data.org/v4/competitions/PL/scorers?limit=50") else { return }
        var req = URLRequest(url: url); req.setValue(apiKey, forHTTPHeaderField: "X-Auth-Token")
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let all = try JSONDecoder().decode(ScorersResponse.self, from: data).scorers
            assisters = all.filter { ($0.assists ?? 0) > 0 }.sorted { ($0.assists ?? 0) > ($1.assists ?? 0) }
        } catch { assistersError = "Failed to load assisters." }
    }

    func fetchTeamMatches(teamId: Int) async {
        guard teamMatches[teamId] == nil else { return }
        guard let url = URL(string: "https://api.football-data.org/v4/teams/\(teamId)/matches?competitions=PL&limit=15") else { return }
        var req = URLRequest(url: url); req.setValue(apiKey, forHTTPHeaderField: "X-Auth-Token")
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            teamMatches[teamId] = try JSONDecoder().decode(TeamMatchesResponse.self, from: data).matches
        } catch {}
    }
}

// MARK: - Root View

struct ContentView: View {
    @State private var viewModel = PLViewModel()

    var body: some View {
        TabView {
            StandingsView(viewModel: viewModel)
                .tabItem { Label("Standings", systemImage: "list.number") }
            FixturesView(viewModel: viewModel)
                .tabItem { Label("Fixtures", systemImage: "calendar") }
            StatsView(viewModel: viewModel)
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
        }
        .tint(.purple)
    }
}

// MARK: - Standings View

struct StandingsView: View {
    @Bindable var viewModel: PLViewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.loadingStandings {
                    ProgressView("Loading standings...").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.standingsError {
                    ErrorView(message: error) { Task { await viewModel.fetchStandings() } }
                } else {
                    standingsTable
                }
            }
            .navigationTitle("Premier League")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await viewModel.fetchStandings() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task { await viewModel.fetchStandings() }
    }

    var standingsTable: some View {
        ScrollView {
            VStack(spacing: 0) {
                tableHeader
                Divider()
                ForEach(Array(viewModel.filteredStandings.enumerated()), id: \.element.id) { index, entry in
                    NavigationLink(destination: TeamDetailView(entry: entry, viewModel: viewModel)) {
                        StandingRowView(entry: entry)
                    }
                    .buttonStyle(.plain)
                    if index < viewModel.filteredStandings.count - 1 {
                        Divider().padding(.leading, 16)
                    }
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding()

            legendView.padding(.horizontal).padding(.bottom)
        }
        .background(Color(.systemGroupedBackground))
        .searchable(text: $viewModel.searchText, prompt: "Search teams...")
    }

    var tableHeader: some View {
        HStack(spacing: 0) {
            Text("#").frame(width: 28, alignment: .center)
            Text("Team").frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 8)
            Text("Form").frame(width: 60, alignment: .center)
            Text("MP").frame(width: 32, alignment: .center)
            Text("GD").frame(width: 36, alignment: .center)
            Text("Pts").frame(width: 36, alignment: .center)
        }
        .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Color(.systemGroupedBackground))
    }

    var legendView: some View {
        VStack(alignment: .leading, spacing: 6) {
            legendItem(color: .blue, label: "UEFA Champions League")
            legendItem(color: .orange, label: "UEFA Europa League")
            legendItem(color: .green, label: "UEFA Conference League")
            legendItem(color: .red, label: "Relegation")
        }.padding(.top, 4)
    }

    func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 12, height: 12)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Standing Row

struct StandingRowView: View {
    let entry: TableEntry

    var positionColor: Color {
        switch entry.position {
        case 1...4: return .blue
        case 5: return .orange
        case 6: return .green
        case 18...20: return .red
        default: return .clear
        }
    }

    var formResults: [String] {
        guard let form = entry.form else { return [] }
        return form.split(separator: ",").map(String.init).suffix(5).map { $0 }
    }

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                if positionColor != .clear {
                    RoundedRectangle(cornerRadius: 3).fill(positionColor)
                        .frame(width: 4, height: 32).offset(x: -12)
                }
                Text("\(entry.position)").font(.subheadline).fontWeight(.medium)
                    .frame(width: 28, alignment: .center)
            }

            HStack(spacing: 8) {
                AsyncImage(url: URL(string: entry.team.crest)) { image in
                    image.resizable().scaledToFit()
                } placeholder: { Circle().fill(Color(.systemGray5)) }
                .frame(width: 24, height: 24)

                Text(entry.team.shortName)
                    .font(.subheadline)
                    .fontWeight(entry.position <= 4 ? .semibold : .regular)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 8)

            HStack(spacing: 3) {
                ForEach(Array(formResults.enumerated()), id: \.offset) { _, result in
                    Circle()
                        .fill(result == "W" ? Color.green : result == "D" ? Color.orange : Color.red)
                        .frame(width: 8, height: 8)
                }
            }
            .frame(width: 60, alignment: .center)

            Text("\(entry.playedGames)").frame(width: 32, alignment: .center)
            Text(entry.goalDifference > 0 ? "+\(entry.goalDifference)" : "\(entry.goalDifference)")
                .frame(width: 36, alignment: .center)
                .foregroundStyle(entry.goalDifference > 0 ? .green : entry.goalDifference < 0 ? .red : .primary)
            Text("\(entry.points)").frame(width: 36, alignment: .center).fontWeight(.semibold)
        }
        .font(.subheadline).padding(.horizontal, 12).padding(.vertical, 10)
        .background(Color(.systemBackground))
    }
}

// MARK: - Fixtures View

struct FixturesView: View {
    @Bindable var viewModel: PLViewModel

    var grouped: [(String, [Match])] {
        let iso = ISO8601DateFormatter()
        let display = DateFormatter()
        display.dateStyle = .full; display.timeStyle = .none; display.timeZone = .current
        var dict: [String: [Match]] = [:]
        for match in viewModel.fixtures {
            let key = iso.date(from: match.utcDate).map { display.string(from: $0) } ?? "Unknown"
            dict[key, default: []].append(match)
        }
        return dict.sorted {
            let df = DateFormatter(); df.dateStyle = .full; df.timeZone = .current
            return (df.date(from: $0.0) ?? .distantPast) > (df.date(from: $1.0) ?? .distantPast)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.loadingFixtures {
                    ProgressView("Loading fixtures...").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.fixturesError {
                    ErrorView(message: error) { Task { await viewModel.fetchFixtures() } }
                } else {
                    fixturesList
                }
            }
            .navigationTitle("Fixtures & Results")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await viewModel.fetchFixtures() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task { await viewModel.fetchFixtures() }
    }

    var fixturesList: some View {
        ScrollView {
            LazyVStack(spacing: 16, pinnedViews: .sectionHeaders) {
                ForEach(grouped, id: \.0) { date, matches in
                    Section {
                        VStack(spacing: 0) {
                            ForEach(Array(matches.enumerated()), id: \.element.id) { index, match in
                                NavigationLink(destination: MatchDetailView(match: match)) {
                                    MatchRowView(match: match)
                                }
                                .buttonStyle(.plain)
                                if index < matches.count - 1 { Divider().padding(.leading, 16) }
                            }
                        }
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    } header: {
                        Text(date)
                            .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20).padding(.vertical, 6)
                            .background(Color(.systemGroupedBackground))
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Match Row

struct MatchRowView: View {
    let match: Match

    var statusBadge: (String, Color) {
        switch match.status {
        case "FINISHED": return ("FT", .secondary)
        case "IN_PLAY": return ("LIVE", .green)
        case "PAUSED": return ("HT", .orange)
        default: return (formattedMatchTime(match.utcDate), .blue)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(statusBadge.0)
                .font(.caption2).fontWeight(.semibold).foregroundStyle(statusBadge.1)
                .frame(width: 40)

            HStack(spacing: 6) {
                Text(match.homeTeam.shortName ?? match.homeTeam.name ?? "TBD")
                    .font(.subheadline)
                    .fontWeight(match.score.winner == "HOME" ? .bold : .regular)
                    .lineLimit(1).frame(maxWidth: .infinity, alignment: .trailing)
                AsyncImage(url: URL(string: match.homeTeam.crest ?? "")) { image in
                    image.resizable().scaledToFit()
                } placeholder: { Circle().fill(Color(.systemGray5)) }
                .frame(width: 22, height: 22)
            }

            if isFinished(match.status), let h = match.score.fullTime.home, let a = match.score.fullTime.away {
                Text("\(h) – \(a)").font(.subheadline).fontWeight(.bold).frame(width: 48, alignment: .center)
            } else {
                Text("vs").font(.subheadline).foregroundStyle(.secondary).frame(width: 48, alignment: .center)
            }

            HStack(spacing: 6) {
                AsyncImage(url: URL(string: match.awayTeam.crest ?? "")) { image in
                    image.resizable().scaledToFit()
                } placeholder: { Circle().fill(Color(.systemGray5)) }
                .frame(width: 22, height: 22)
                Text(match.awayTeam.shortName ?? match.awayTeam.name ?? "TBD")
                    .font(.subheadline)
                    .fontWeight(match.score.winner == "AWAY" ? .bold : .regular)
                    .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
    }
}

// MARK: - Match Detail View

struct MatchDetailView: View {
    let match: Match

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text(formattedMatchDate(match.utcDate))
                    .font(.subheadline).foregroundStyle(.secondary).padding(.top)

                VStack(spacing: 20) {
                    HStack(spacing: 0) {
                        VStack(spacing: 8) {
                            AsyncImage(url: URL(string: match.homeTeam.crest ?? "")) { image in
                                image.resizable().scaledToFit()
                            } placeholder: { Circle().fill(Color(.systemGray5)) }
                            .frame(width: 56, height: 56)
                            Text(match.homeTeam.name ?? "TBD")
                                .font(.subheadline).fontWeight(.semibold)
                                .multilineTextAlignment(.center).lineLimit(2)
                        }.frame(maxWidth: .infinity)

                        VStack(spacing: 4) {
                            if isFinished(match.status), let h = match.score.fullTime.home, let a = match.score.fullTime.away {
                                Text("\(h) – \(a)").font(.system(size: 36, weight: .bold))
                                Text("Full Time").font(.caption).foregroundStyle(.secondary)
                            } else {
                                Text("VS").font(.title).fontWeight(.bold).foregroundStyle(.secondary)
                                Text("Upcoming")
                                    .font(.caption).fontWeight(.semibold).foregroundStyle(.blue)
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.12)).clipShape(Capsule())
                            }
                        }.frame(width: 100)

                        VStack(spacing: 8) {
                            AsyncImage(url: URL(string: match.awayTeam.crest ?? "")) { image in
                                image.resizable().scaledToFit()
                            } placeholder: { Circle().fill(Color(.systemGray5)) }
                            .frame(width: 56, height: 56)
                            Text(match.awayTeam.name ?? "TBD")
                                .font(.subheadline).fontWeight(.semibold)
                                .multilineTextAlignment(.center).lineLimit(2)
                        }.frame(maxWidth: .infinity)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                if isFinished(match.status), let h = match.score.halfTime.home, let a = match.score.halfTime.away {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Half Time Score")
                            .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                        HStack {
                            Text(match.homeTeam.shortName ?? "Home").frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(h) – \(a)").fontWeight(.semibold)
                            Text(match.awayTeam.shortName ?? "Away").frame(maxWidth: .infinity, alignment: .trailing)
                        }.font(.subheadline)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

                if let matchday = match.matchday {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar").foregroundStyle(.secondary)
                        Text("Matchday \(matchday)").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Match Detail")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Stats View (Scorers + Assisters)

struct StatsView: View {
    @Bindable var viewModel: PLViewModel
    @State private var selectedStat = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Stat", selection: $selectedStat) {
                    Text("Top Scorers").tag(0)
                    Text("Top Assisters").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                if selectedStat == 0 {
                    scorersContent
                } else {
                    assistersContent
                }
            }
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            if selectedStat == 0 { await viewModel.fetchScorers() }
                            else { await viewModel.fetchAssisters() }
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task { await viewModel.fetchScorers() }
        .task { await viewModel.fetchAssisters() }
    }

    // MARK: Scorers

    var scorersContent: some View {
        Group {
            if viewModel.loadingScorers {
                ProgressView("Loading scorers...").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.scorersError {
                ErrorView(message: error) { Task { await viewModel.fetchScorers() } }
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        scorersHeader
                        Divider()
                        ForEach(Array(viewModel.scorers.enumerated()), id: \.element.id) { index, scorer in
                            NavigationLink(destination: PlayerDetailView(scorer: scorer, rank: index + 1, statLabel: "Goals", statValue: scorer.goals)) {
                                PlayerRowView(rank: index + 1, scorer: scorer, primaryStat: "\(scorer.goals)", primaryColor: .purple, secondaryStat: "\(scorer.assists ?? 0)", penaltyStat: "\(scorer.penalties ?? 0)", showPenalty: true)
                            }
                            .buttonStyle(.plain)
                            if index < viewModel.scorers.count - 1 { Divider().padding(.leading, 16) }
                        }
                    }
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()
                }
                .background(Color(.systemGroupedBackground))
            }
        }
    }

    var scorersHeader: some View {
        HStack {
            Text("#").frame(width: 32, alignment: .center)
            Text("Player").frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 8)
            Text("G").frame(width: 36, alignment: .center)
            Text("A").frame(width: 36, alignment: .center)
            Text("Pen").frame(width: 36, alignment: .center)
        }
        .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: Assisters

    var assistersContent: some View {
        Group {
            if viewModel.loadingAssisters {
                ProgressView("Loading assisters...").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.assistersError {
                ErrorView(message: error) { Task { await viewModel.fetchAssisters() } }
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        assistersHeader
                        Divider()
                        ForEach(Array(viewModel.assisters.enumerated()), id: \.element.id) { index, scorer in
                            NavigationLink(destination: PlayerDetailView(scorer: scorer, rank: index + 1, statLabel: "Assists", statValue: scorer.assists ?? 0)) {
                                PlayerRowView(rank: index + 1, scorer: scorer, primaryStat: "\(scorer.assists ?? 0)", primaryColor: .blue, secondaryStat: "\(scorer.goals)", penaltyStat: nil, showPenalty: false)
                            }
                            .buttonStyle(.plain)
                            if index < viewModel.assisters.count - 1 { Divider().padding(.leading, 16) }
                        }
                    }
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()
                }
                .background(Color(.systemGroupedBackground))
            }
        }
    }

    var assistersHeader: some View {
        HStack {
            Text("#").frame(width: 32, alignment: .center)
            Text("Player").frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 8)
            Text("A").frame(width: 36, alignment: .center)
            Text("G").frame(width: 36, alignment: .center)
        }
        .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Player Row View (shared for scorers + assisters)

struct PlayerRowView: View {
    let rank: Int
    let scorer: Scorer
    let primaryStat: String
    let primaryColor: Color
    let secondaryStat: String
    let penaltyStat: String?
    let showPenalty: Bool

    var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return Color(.systemGray3)
        case 3: return .orange
        default: return .clear
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                if rankColor != .clear { Circle().fill(rankColor.opacity(0.25)).frame(width: 26, height: 26) }
                Text("\(rank)").font(.subheadline).fontWeight(rank <= 3 ? .bold : .regular)
            }.frame(width: 32, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(scorer.player.name).font(.subheadline).fontWeight(.semibold).lineLimit(1)
                HStack(spacing: 4) {
                    AsyncImage(url: URL(string: scorer.team.crest)) { image in
                        image.resizable().scaledToFit()
                    } placeholder: { Circle().fill(Color(.systemGray5)) }
                    .frame(width: 14, height: 14)
                    Text(scorer.team.shortName).font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 8)

            Text(primaryStat).font(.subheadline).fontWeight(.bold).foregroundStyle(primaryColor)
                .frame(width: 36, alignment: .center)
            Text(secondaryStat).font(.subheadline).foregroundStyle(.secondary)
                .frame(width: 36, alignment: .center)
            if showPenalty, let pen = penaltyStat {
                Text(pen).font(.subheadline).foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .center)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Color(.systemBackground))
    }
}

// MARK: - Player Detail View

struct PlayerDetailView: View {
    let scorer: Scorer
    let rank: Int
    let statLabel: String
    let statValue: Int

    var formattedDOB: String {
        guard let dob = scorer.player.dateOfBirth,
              let date = ISO8601DateFormatter().date(from: dob) else { return "N/A" }
        let df = DateFormatter(); df.dateStyle = .long
        return df.string(from: date)
    }

    var age: Int? {
        guard let dob = scorer.player.dateOfBirth,
              let date = ISO8601DateFormatter().date(from: dob) else { return nil }
        return Calendar.current.dateComponents([.year], from: date, to: Date()).year
    }

    var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return Color(.systemGray3)
        case 3: return .orange
        default: return .purple
        }
    }

    func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 { return "\(parts.first!.prefix(1))\(parts.last!.prefix(1))" }
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 10) {
                    ZStack {
                        Circle().fill(rankColor.opacity(0.15)).frame(width: 90, height: 90)
                        Text(initials(from: scorer.player.name))
                            .font(.largeTitle).fontWeight(.bold).foregroundStyle(rankColor)
                    }
                    Text(scorer.player.name).font(.title2).fontWeight(.bold)
                    HStack(spacing: 8) {
                        AsyncImage(url: URL(string: scorer.team.crest)) { image in
                            image.resizable().scaledToFit()
                        } placeholder: { Circle().fill(Color(.systemGray5)) }
                        .frame(width: 20, height: 20)
                        Text(scorer.team.name).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text("Rank #\(rank)")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(rankColor)
                        .padding(.horizontal, 12).padding(.vertical, 4)
                        .background(rankColor.opacity(0.12)).clipShape(Capsule())
                }
                .padding(.top)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    StatCard(label: "Goals", value: "\(scorer.goals)", color: .purple)
                    StatCard(label: "Assists", value: "\(scorer.assists ?? 0)", color: .blue)
                    StatCard(label: "Penalties", value: "\(scorer.penalties ?? 0)", color: .orange)
                }.padding(.horizontal)

                if let matches = scorer.playedMatches {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        StatCard(label: "Matches", value: "\(matches)", color: .green)
                        StatCard(label: "\(statLabel)/Game",
                                 value: matches > 0 ? String(format: "%.2f", Double(statValue) / Double(matches)) : "0.00",
                                 color: .teal)
                    }.padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Player Info").font(.headline).padding(.bottom, 2)
                    infoRow(label: "Nationality", value: scorer.player.nationality ?? "N/A")
                    Divider()
                    infoRow(label: "Date of Birth", value: formattedDOB)
                    if let age = age {
                        Divider()
                        infoRow(label: "Age", value: "\(age) years old")
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal).padding(.bottom)
            }
        }
        .navigationTitle(scorer.player.name)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }

    func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }.font(.subheadline)
    }
}

// MARK: - Team Detail View

struct TeamDetailView: View {
    let entry: TableEntry
    @Bindable var viewModel: PLViewModel

    var allMatches: [Match] { viewModel.teamMatches[entry.team.id] ?? [] }
    var recentMatches: [Match] { allMatches.filter { isFinished($0.status) } }
    var upcomingMatches: [Match] { allMatches.filter { isUpcoming($0.status) } }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    AsyncImage(url: URL(string: entry.team.crest)) { image in
                        image.resizable().scaledToFit()
                    } placeholder: { RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray5)) }
                    .frame(width: 80, height: 80)

                    Text(entry.team.name).font(.title2).fontWeight(.bold)

                    HStack(spacing: 4) {
                        Text("Position \(entry.position)").font(.subheadline).foregroundStyle(.secondary)
                        Text("·").foregroundStyle(.secondary)
                        Text("\(entry.points) pts").font(.subheadline).fontWeight(.semibold).foregroundStyle(.purple)
                    }

                    if let form = entry.form, !form.isEmpty {
                        HStack(spacing: 6) {
                            Text("Form").font(.caption).foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                ForEach(Array(form.split(separator: ",").map(String.init).suffix(5).enumerated()), id: \.offset) { _, r in
                                    Text(r).font(.caption2).fontWeight(.bold).foregroundStyle(.white)
                                        .frame(width: 20, height: 20)
                                        .background(r == "W" ? Color.green : r == "D" ? Color.orange : Color.red)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                            }
                        }
                    }
                }
                .padding(.top)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    StatCard(label: "Points", value: "\(entry.points)", color: .purple)
                    StatCard(label: "Played", value: "\(entry.playedGames)", color: .blue)
                    StatCard(label: "Won", value: "\(entry.won)", color: .green)
                    StatCard(label: "Drawn", value: "\(entry.draw)", color: .orange)
                    StatCard(label: "Lost", value: "\(entry.lost)", color: .red)
                    StatCard(label: "Goal Diff",
                             value: entry.goalDifference > 0 ? "+\(entry.goalDifference)" : "\(entry.goalDifference)",
                             color: entry.goalDifference >= 0 ? .green : .red)
                }.padding(.horizontal)

                HStack(spacing: 16) {
                    StatCard(label: "Goals For", value: "\(entry.goalsFor)", color: .green)
                    StatCard(label: "Goals Against", value: "\(entry.goalsAgainst)", color: .red)
                }.padding(.horizontal)

                if !recentMatches.isEmpty {
                    matchSection(title: "Recent Results", matches: Array(recentMatches.prefix(5)))
                }

                if !upcomingMatches.isEmpty {
                    matchSection(title: "Upcoming Fixtures", matches: Array(upcomingMatches.prefix(5)))
                }
            }
            .padding(.bottom)
        }
        .navigationTitle(entry.team.shortName)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .task { await viewModel.fetchTeamMatches(teamId: entry.team.id) }
    }

    func matchSection(title: String, matches: [Match]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).padding(.horizontal)
            VStack(spacing: 0) {
                ForEach(Array(matches.enumerated()), id: \.element.id) { index, match in
                    NavigationLink(destination: MatchDetailView(match: match)) {
                        MatchRowView(match: match)
                    }
                    .buttonStyle(.plain)
                    if index < matches.count - 1 { Divider().padding(.leading, 16) }
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(value).font(.title2).fontWeight(.bold).foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Error View

struct ErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(.orange)
            Text(message).multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button("Try Again", action: retry).buttonStyle(.borderedProminent).tint(.purple)
        }.padding()
    }
}
