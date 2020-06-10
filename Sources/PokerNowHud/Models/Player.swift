//
//  Player.swift
//  ArgumentParser
//
//  Created by PJ Gray on 6/2/20.
//

import Foundation
import SwiftyTextTable

extension Player: TextTableRepresentable {
    static var columnHeaders: [String] {
        return ["Name", "Total VPIP %", "Total Hands", "Session VPIP %", "Session Hands"]
    }

    var tableValues: [CustomStringConvertible] {
        return ["\(self.name ?? "error")\(self.playerType)", self.totalVPIP, self.statsHandsSeen + self.handsSeen, self.vpip, self.handsSeen]
    }
}

class Player: NSObject, Codable {
    enum Status : String, Codable {
        case inGame, watching, quiting, requestedGameIngress, waitingNextGameToEnter, standingUp
    }
    
    var id: String?
    var name: String?
    var status: Status?
    
    var updatedCurrentHandSeen = false
    var updatedCurrentHandPlayed = false
    
    var statsHandsSeen: Int = 0
    var statsHandsPlayed: Int = 0
    
    var handsSeen: Int = 0
    var handsPlayed: Int = 0
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case status
    }
    
    var totalVPIP: Int {
        get {
            return Int((Double(self.handsPlayed + self.statsHandsPlayed) / Double(self.handsSeen + self.statsHandsSeen)) * 100.0)
        }
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
            if (self.handsSeen + self.statsHandsSeen) > 20 {
                if self.totalVPIP > 40 { playerType = "🐠" }
                else if self.totalVPIP >= 20 { playerType = "💣" }
                else if self.totalVPIP >= 12 { playerType = "🔒" }
                else if self.totalVPIP < 12 { playerType = "🧗‍♀️" }
            }
            
            // basic pfr types
            
            // specialty types
            // add 🐳  for high vpip low pfr

            return playerType
        }
    }
}
