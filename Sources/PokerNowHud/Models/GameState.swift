//
//  GameState.swift
//  ArgumentParser
//
//  Created by PJ Gray on 6/2/20.
//

import Foundation

class GameState: NSObject, Codable {
    
    var players: [String:Player]?
    var gT: String?
}
