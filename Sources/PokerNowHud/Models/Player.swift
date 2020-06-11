//
//  Player.swift
//  ArgumentParser
//
//  Created by PJ Gray on 6/2/20.
//

import Foundation
import SwiftyTextTable
import Rainbow

extension Player: TextTableRepresentable {
    static var columnHeaders: [String] {
        return ["Name", "VPIP %", "PFR %", "Hands", "Session VPIP %", "Session PFR %", "Session Hands"]
    }

    var tableValues: [CustomStringConvertible] {
        return ["\(self.name ?? "error")\(self.playerType)".utf8, self.totalVPIP, self.totalPFR, self.statsHandsSeen + self.handsSeen, self.vpip, self.pfr, self.handsSeen]
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
    var updatedCurrentHandPFRaised = false
    
    var statsHandsSeen: Int = 0
    var statsHandsPlayed: Int = 0
    var statsHandsPFRaised: Int = 0
    
    var handsSeen: Int = 0
    var handsPlayed: Int = 0
    var handsPFRaised: Int = 0
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case status
    }
    
    var totalPFR: Int {
        get {
            return Int((Double(self.handsPFRaised + self.statsHandsPFRaised) / Double(self.handsSeen + self.statsHandsSeen)) * 100.0)
        }
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

    var pfr: Int {
        get {
            return Int((Double(self.handsPFRaised) / Double(self.handsSeen)) * 100.0)
        }
    }

    var playerType: String {
        get {
            var playerType = ""
            
            if (self.handsSeen + self.statsHandsSeen) > 20 {
                // basic vpip types
                if self.totalVPIP > 40 { playerType = "🐠" }
                else if self.totalVPIP >= 20 { playerType = "💣" }
                else if self.totalVPIP >= 12 { playerType = "🔒" }
                else if self.totalVPIP < 12 { playerType = "🧗‍♀️" }

                // basic pfr types
                if self.totalPFR > 30 { playerType = playerType + "🎢" }
                else if self.totalPFR > 10 { playerType = playerType + "⚔️" }
                else if self.totalPFR > 2 { playerType = playerType + "🐭" }
                else { playerType = playerType + "📞" }
                
                // specialty types
                if (self.totalVPIP >= 30) && (self.totalPFR >= 30) { playerType = "🐴" }
                if (self.totalVPIP >= 50) && (self.totalPFR <= 5) { playerType = "🐳" }
            }
            

            return playerType
        }
    }
}
