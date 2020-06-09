//
//  Player.swift
//  ArgumentParser
//
//  Created by PJ Gray on 6/2/20.
//

import Foundation

class Player: NSObject, Codable {
    enum Status : String, Codable {
        case inGame, watching, quiting, requestedGameIngress, waitingNextGameToEnter, standingUp
    }
    
    var id: String?
    var name: String?
    var status: Status?
    
    var updatedCurrentHandSeen = false
    var updatedCurrentHandPlayed = false
    
    var handsSeen: Int = 0
    var handsPlayed: Int = 0
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case status
    }
}
