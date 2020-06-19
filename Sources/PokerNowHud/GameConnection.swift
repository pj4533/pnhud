//
//  GameConnection.swift
//  ArgumentParser
//
//  Created by PJ Gray on 6/2/20.
//

import Foundation
import SocketIO
import SwiftCSV
import Rainbow

class GameConnection: NSObject {

    var debug: Bool = false
    var manager: SocketManager?
    var connected: Bool = false
    
    var allPlayers: [Player] = []
    var players: [Player] = []

    var loadedStats: [String:[String:Int]] = [:]
    
    var ready = false
    var loadedRUP = false
    var firstMessage = true
    
    var showedResults = false
    var isPreFlop = true
    
    init(gameId: String, statsFilename: String?) {
        super.init()

        if let statsFilename = statsFilename {
            print("Reading stat file...")
            do {
                let csvFile: CSV = try CSV(url: URL(fileURLWithPath: statsFilename))
                for row in csvFile.namedRows.reversed() {
                    if let player = row["Player"], let hands = Int((row["Hands"] ?? "").replacingOccurrences(of: ",", with: "")), let countVPIP = Int((row["Count VPIP"] ?? "").replacingOccurrences(of: ",", with: "")), let countPFR = Int((row["Count PFR"] ?? "").replacingOccurrences(of: ",", with: "")) {
                        self.loadedStats[player] = [
                            "hands" : hands,
                            "countVPIP" : countVPIP,
                            "countPFR" : countPFR
                        ]
                    }
                }
            } catch let parseError as CSVParseError {
                print(parseError)
            } catch {
                print("Error loading file")
            }
        }
        
        let group = DispatchGroup()
        
        print("Connecting to: \(gameId)...")
        let request = URLRequest(url: URL(string: "https://www.pokernow.club/games/\(gameId)")!)

        group.enter()
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard
                let url = response?.url,
                let httpResponse = response as? HTTPURLResponse,
                let fields = httpResponse.allHeaderFields as? [String: String]
            else { return }

            let cookies = HTTPCookie.cookies(withResponseHeaderFields: fields, for: url)
            HTTPCookieStorage.shared.setCookies(cookies, for: url, mainDocumentURL: nil)
            for cookie in cookies {
                var cookieProperties = [HTTPCookiePropertyKey: Any]()
                cookieProperties[.name] = cookie.name
                cookieProperties[.value] = cookie.value
                cookieProperties[.domain] = cookie.domain
                cookieProperties[.path] = cookie.path
                cookieProperties[.version] = cookie.version
                cookieProperties[.expires] = Date().addingTimeInterval(31536000)

                let newCookie = HTTPCookie(properties: cookieProperties)
                HTTPCookieStorage.shared.setCookie(newCookie!)
            }

            group.leave()
            
        }
        task.resume()


        group.notify(queue: DispatchQueue.main) {
            self.manager = SocketManager(socketURL: URL(string: "http://www.pokernow.club/")!, config: [.log(false), .cookies(HTTPCookieStorage.shared.cookies!), .forceWebsockets(true), .connectParams(["gameID":gameId])])
            
            let socket = self.manager?.defaultSocket
            socket?.on(clientEvent: .connect) {data, ack in
                if !self.connected {
                    socket?.emit("action", ["type":"RUP"])
                   self.connected = true
                }
            }

            socket?.on("rup", callback: { (json, ack) in
                do {
                    let data = try JSONSerialization.data(withJSONObject: json, options: [])
                    let decoder = JSONDecoder()
                    let state = try decoder.decode([GameState].self, from: data)

                    self.players = state.first?.players?.map({$0.value}) ?? []
                    self.allPlayers = self.players
                    for player in self.players {
                        if let previousStats = self.loadedStats[player.name ?? ""] {
                            print("\tfound previous stats on player: \(player.name ?? "error")")
                            player.statsHandsSeen = (previousStats["hands"] ?? 0)
                            player.statsHandsPlayed = (previousStats["countVPIP"] ?? 0)
                            player.statsHandsPFRaised = (previousStats["countPFR"] ?? 0)
                        }
                    }
                    
                    if self.debug {
                        print("In Game Players (FROM RUP): ")
                        print(state.first?.players?.values.filter({$0.status == .inGame}).map({"\($0.id ?? "") : \($0.name ?? "")"}) ?? [])
                    }
                } catch let error {
                    if self.debug {
                        print(error)
                    }
                }
                self.loadedRUP = true
            })

            socket?.on("gC", callback: { (newStateArray, ack) in
                if self.loadedRUP {
                    if let json = newStateArray.first as? [String:Any] {
                        do {
                            let data = try JSONSerialization.data(withJSONObject: json, options: [])
                            let decoder = JSONDecoder()
                            let state = try decoder.decode(GameState.self, from: data)
                            
                            if state.players != nil {
                                for playerId in state.players?.map({$0.key}) ?? [] {
                                    if let player = state.players?[playerId] {
                                        if player.status == .requestedGameIngress {
                                            self.addPlayerId(playerId: playerId, player: player)
                                        } else if player.status == .quiting {
                                            print("**** QUITING PLAYER:   \(playerId)")
                                            self.players.removeAll(where: {$0.id == playerId})
                                        } else {
                                            if (player.status != nil) && (player.status != .watching) && (player.disconnectedSince == nil) {
                                                if !self.players.map({$0.id}).contains(playerId) {
                                                    print("STATUS: \(player.status?.rawValue ?? "\(json["players"] ?? [])")")
                                                    self.addPlayerId(playerId: playerId, player: player)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        } catch let error {
                            if self.debug {
                                print(error)
                            }
                        }

                        if self.ready {
                            if let tb = json["tB"] as? [String:Any] {
                                for key in tb.keys {
                                    if let player = self.players.filter({$0.id == key}).first {
                                        if !player.updatedCurrentHandSeen {
                                            if self.debug {
                                                print("-> \(player.name ?? "error") saw hand.")
                                            }
                                            self.showedResults = false
                                            player.handsSeen = player.handsSeen + 1
                                            player.updatedCurrentHandSeen = true
                                        }
                                    }
                                }
                                if let _ = Int("\(tb.values.first ?? "")"), tb.keys.count == 1 {
                                    if let player = self.players.filter({$0.id == tb.keys.first}).first {
                                        if !player.updatedCurrentHandPlayed {
                                            if self.debug {
                                                print("-> \(player.name ?? "error") played hand.")
                                            }
                                            player.handsPlayed = player.handsPlayed + 1
                                            player.updatedCurrentHandPlayed = true
                                        }
                                        
                                        if let _ = Int("\(json["cHB"] ?? "")"), self.isPreFlop {
                                            if !player.updatedCurrentHandPFRaised {
                                                if self.debug {
                                                    print("-> \(player.name ?? "error") raised preflop.")
                                                }
                                                player.handsPFRaised = player.handsPFRaised + 1
                                                player.updatedCurrentHandPFRaised = true
                                            }
                                        }
                                    }
                                }
                            } else if let pgs = json["pGS"] as? [String:Any] {
                                for key in pgs.keys {
                                    if let player = self.players.filter({$0.id == key}).first {
                                        if !player.updatedCurrentHandSeen {
                                            if self.debug {
                                                print("-> \(player.name ?? "error") saw hand.")
                                            }
                                            self.showedResults = false
                                            player.handsSeen = player.handsSeen + 1
                                            player.updatedCurrentHandSeen = true
                                        }
                                    }
                                }
                            }

                            if (json["gT"] as? String) == "flop" {
                                self.isPreFlop = false
                            }
                        } else {
                            if self.firstMessage {
                                print("--> Waiting for end of current hand...")
                                self.firstMessage = false
                            }
                        }


                        if (json["gT"] as? String) == "gameResult" {
                            if self.ready {
                                if !self.showedResults {
                                    for player in self.players {
                                        player.updatedCurrentHandPlayed = false
                                        player.updatedCurrentHandSeen = false
                                        player.updatedCurrentHandPFRaised = false
                                    }
                                    // clear screen
                                    if !self.debug {
                                        print("\u{001B}[2J")
                                    }

                                    // print table
                                    self.renderTextTable()
                                    self.showedResults = true
                                }
                                self.isPreFlop = true
                            } else {
                                print("--> Saw end of hand.  Recording stats now...")
                                self.ready = true
                            }
                        }
                    }
                }
            })

            socket?.connect()
        }
        

    }

    func addPlayerId(playerId: String, player: Player) {
        if !self.players.map({$0.id}).contains(playerId) {
            if let playerName = player.name {
                print("**** ADDING PLAYER: \(playerName)  STATUS: \(player.status?.rawValue ?? "unknown")")
                player.id = playerId
                if let previousStats = self.loadedStats[playerName] {
                    print("\tfound previous stats on player: \(playerName)")
                    player.statsHandsSeen = (previousStats["hands"] ?? 0)
                    player.statsHandsPlayed = (previousStats["countVPIP"] ?? 0)
                    player.statsHandsPFRaised = (previousStats["countPFR"] ?? 0)
                }
                self.players.append(player)
                if !self.allPlayers.map({$0.id}).contains(playerId) {
                    self.allPlayers.append(player)
                }
            } else if self.allPlayers.map({$0.id}).contains(playerId) {
                if let previousPlayer = self.allPlayers.first(where: {$0.id == playerId}), let playerName = previousPlayer.name {
                    print("**** ADDING PREVIOUS PLAYER: \(playerName)  STATUS: \(previousPlayer.status?.rawValue ?? "unknown")")
                    if let previousStats = self.loadedStats[playerName] {
                        print("\tfound previous stats on player: \(playerName)")
                        previousPlayer.statsHandsSeen = (previousStats["hands"] ?? 0)
                        previousPlayer.statsHandsPlayed = (previousStats["countVPIP"] ?? 0)
                        previousPlayer.statsHandsPFRaised = (previousStats["countPFR"] ?? 0)
                    }
                    self.players.append(previousPlayer)
                }
            } else {
                print("**** ERROR PLAYER NAME NOT FOUND WHEN ADDING NEW PLAYER")
            }
        }
    }
    
    func renderTextTable() {
        let headersString = String(format:"%@ %@ %@ %@ %@ %@ %@ %@ %@",
        "Name".padding(toLength: 20, withPad: " ", startingAt: 0),
        "VPIP %".padding(toLength: 8, withPad: " ", startingAt: 0),
        "PFR %".padding(toLength: 8, withPad: " ", startingAt: 0),
        "PFR/VPIP %".padding(toLength: 8, withPad: " ", startingAt: 0),
        "Hands".padding(toLength: 8, withPad: " ", startingAt: 0),
        "Session VPIP %".padding(toLength: 15, withPad: " ", startingAt: 0),
        "Session PFR %".padding(toLength: 15, withPad: " ", startingAt: 0),
        "Session PFR/VPIP %".padding(toLength: 17, withPad: " ", startingAt: 0),
        "Session Hands".padding(toLength: 15, withPad: " ", startingAt: 0))
        
        print(headersString.white.bold)
        print("".padding(toLength: headersString.count, withPad: "=", startingAt: 0).white.bold)

        for player in self.players.filter({$0.handsSeen > 0}) {
          let nameAndType = "\(player.name ?? "error")\(player.playerType)"
            var namePadding = 20
            
            // emoji hacks
            if nameAndType.contains("🐭") ||
                nameAndType.contains("📞") ||
                nameAndType.contains("🐴") ||
                nameAndType.contains("🧗‍♀️") ||
                nameAndType.contains("🐳") {
                namePadding = 20
            } else {
                if #available(OSX 10.12.2, *) {
                    namePadding = nameAndType.containsEmoji ? 21 : 20
                }
            }
            
            print(String(format:"%@ %@ %@ %@ %@ %@ %@ %@ %@",
                         "\(nameAndType)".padding(toLength: namePadding, withPad: " ", startingAt: 0),
                         "\(player.totalVPIP)".padding(toLength: 8, withPad: " ", startingAt: 0),
                         "\(player.totalPFR)".padding(toLength: 8, withPad: " ", startingAt: 0),
                         "\(player.totalVPIPPFR)".padding(toLength: 8, withPad: " ", startingAt: 0),
                         "\(player.handsSeen + player.statsHandsSeen)".padding(toLength: 8, withPad: " ", startingAt: 0),
                         "\(player.vpip)".padding(toLength: 15, withPad: " ", startingAt: 0),
                         "\(player.pfr)".padding(toLength: 15, withPad: " ", startingAt: 0),
                         "\(player.vpipPFR)".padding(toLength: 17, withPad: " ", startingAt: 0),
                         "\(player.handsSeen)".padding(toLength: 15, withPad: " ", startingAt: 0)))
            print("".padding(toLength: headersString.count, withPad: "-", startingAt: 0))
        }
    }
    
    
}
