# PLStats

A native iOS Premier League stats app built with SwiftUI — inspired by FotMob. Get live standings, fixtures, results, top scorers, and top assisters for the current Premier League season, all powered by the [football-data.org](https://www.football-data.org) API.

## Screenshots

> _Add screenshots here once available_

## Features

- **Live Standings** — full Premier League table with points, goal difference, form indicators, and Champions League / relegation zone highlighting
- **Fixtures & Results** — match results and upcoming fixtures grouped by date, with full-time and half-time scores
- **Top Scorers & Assisters** — leaderboard with goals, assists, and penalties, including per-game averages
- **Team Detail View** — per-team stats (W/D/L, GF, GA, GD) plus recent results and upcoming fixtures
- **Player Detail View** — nationality, age, goals, assists, penalties, and goals-per-game ratio
- **Match Detail View** — full-time and half-time scores with team crests
- **Search** — filter the standings table by team name in real time

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift |
| UI Framework | SwiftUI |
| Architecture | MVVM with `@Observable` |
| Concurrency | `async/await` + `URLSession` |
| Networking | REST API (football-data.org v4) |
| Image Loading | `AsyncImage` |
| Navigation | `NavigationStack` + `TabView` |
| IDE | Xcode |

## Architecture

The app follows the **MVVM** pattern using Swift's `@Observable` macro for reactive state management. All network calls are handled asynchronously via `async/await`, keeping the UI thread non-blocking. A single `PLViewModel` manages state for standings, fixtures, scorers, assisters, and per-team match history — each fetched independently with loading and error states.

## Getting Started

1. Clone the repo
   ```bash
   git clone https://github.com/hpadi02/PLStats.git
   ```
2. Open `PLStats.xcodeproj` in Xcode
3. Get a free API key at [football-data.org](https://www.football-data.org/client/register)
4. Replace the `apiKey` value in `PLViewModel` with your key
5. Build and run on the iOS Simulator or a physical device (iOS 17+)

## API

This app uses the [football-data.org](https://www.football-data.org) REST API (v4). The free tier provides access to Premier League standings, fixtures, and top scorer data.

| Endpoint | Usage |
|---|---|
| `/competitions/PL/standings` | League table |
| `/competitions/PL/matches` | Fixtures and results |
| `/competitions/PL/scorers` | Top scorers and assisters |
| `/teams/{id}/matches` | Per-team match history |

## License

MIT
