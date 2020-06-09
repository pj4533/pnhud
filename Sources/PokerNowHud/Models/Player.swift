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
    
    var vpip: Int {
        get {
            return Int((Double(self.handsPlayed) / Double(self.handsSeen)) * 100.0)
        }
    }
    
    var playerType: String {
        get {
            var playerType = ""
            
            // basic vpip types
            if self.handsSeen > 20 {
                if self.vpip > 40 { playerType = "🐠" }
                else if self.vpip >= 20 { playerType = "💣" }
                else if self.vpip >= 12 { playerType = "🔒" }
                else if self.vpip < 12 { playerType = "🧗‍♀️" }
            }
            
            // basic pfr types
            
            // specialty types
            // add 🐳  for high vpip low pfr

            return playerType
        }
    }
}
