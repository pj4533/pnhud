import Foundation
import ArgumentParser

struct PokerNowHud: ParsableCommand {
    static let configuration = CommandConfiguration(
    	commandName: "pnhud",
        abstract: "Command line driven heads up display for PokerNow.club"
    )

    @Argument(help: "Poker Now Game Id")
    var gameId: String

	func run() {

		    // // explicitly exit the program after response is handled
		    // exit(EXIT_SUCCESS)
        let _ = GameConnection(gameId: self.gameId)
        
        
		// Run GCD main dispatcher, this function never returns, call exit() elsewhere to quit the program or it will hang
		dispatchMain()
    }
}

PokerNowHud.main()
