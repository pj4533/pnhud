# pnhud
Terminal based heads up display for PokerNow tables

```
OVERVIEW: Command line driven heads up display for PokerNow.club

USAGE: pnhud <game-id> [--stats <stats>]

ARGUMENTS:
  <game-id>               Poker Now Game Id

OPTIONS:
  -s, --stats <stats>     Stats File
  -h, --help              Show help information.

```

### Helpful Commands

`swift build` Builds app to the `.build` folder

`swift build -c release` Build a release version

`./.build/debug/pnhud` Runs app after building

`swift run pnhud` Runs app directly

`swift package generate-xcodeproj` Generates an xcode project file


### Example

![screenshot](pnhud.png)
