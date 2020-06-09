//
//  GameConnection.swift
//  ArgumentParser
//
//  Created by PJ Gray on 6/2/20.
//

import Foundation
import SocketIO
import SwiftCSV

class GameConnection: NSObject {

    var debug: Bool = false
    var manager: SocketManager?
    var connected: Bool = false
    
    var players: [Player] = []

    var loadedStats: [String:[String:Int]] = [:]
    
    var showedResults = false
    
    init(gameId: String) {
        super.init()

        print("Reading stat file...")
        do {
            let csvFile: CSV = try CSV(url: URL(fileURLWithPath: "vpip_pfr.csv"))
            for row in csvFile.namedRows.reversed() {
                if let player = row["Player"], let hands = Int(row["Hands"] ?? ""), let countVPIP = Int(row["Count VPIP"] ?? ""), let countPFR = Int(row["Count PFR"] ?? "") {
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
                    for player in self.players {
                        if let previousStats = self.loadedStats[player.name ?? ""] {
                            print("\tfound previous stats on player: \(player.name ?? "error")")
                            player.handsSeen = player.handsSeen + (previousStats["hands"] ?? 0)
                            player.handsPlayed = player.handsPlayed + (previousStats["countVPIP"] ?? 0)
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
            })

            socket?.on("gC", callback: { (newStateArray, ack) in
                if let json = newStateArray.first as? [String:Any] {
                    do {
                        let data = try JSONSerialization.data(withJSONObject: json, options: [])
                        let decoder = JSONDecoder()
                        let state = try decoder.decode(GameState.self, from: data)
                        
                        if state.players != nil {
                            for playerId in state.players?.map({$0.key}) ?? [] {
                                if let player = state.players?[playerId] {
                                    if player.status == .requestedGameIngress {
                                        print("**** ADDING PLAYER:   \(player.name ?? "error")")
                                        player.id = playerId
                                        if let previousStats = self.loadedStats[player.name ?? ""] {
                                            print("\tfound previous stats on player: \(player.name ?? "error")")
                                            player.handsSeen = player.handsSeen + (previousStats["hands"] ?? 0)
                                            player.handsPlayed = player.handsPlayed + (previousStats["countVPIP"] ?? 0)
                                        }
                                        self.players.append(player)
                                    }
                                    if player.status == .quiting {
                                        print("**** QUITING PLAYER:   \(playerId)")
                                        self.players.removeAll(where: {$0.id == playerId})
                                    }
                                }
                            }
                        }
                    } catch let error {
                        if self.debug {
                            print(error)
                        }
                    }

                    
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

                    
                    if (json["gT"] as? String) == "gameResult" {
                        if !self.showedResults {
                            print("******************** END OF HAND ******************")
                            for player in self.players {
                                player.updatedCurrentHandPlayed = false
                                player.updatedCurrentHandSeen = false
                                if player.handsSeen > 0 {
                                    print("\(player.name ?? "error")\(player.playerType)\t\tVPIP: \(player.vpip)% (\(player.handsPlayed)/\(player.handsSeen))")
                                }
                            }
                            print("****************************************************")
                            self.showedResults = true
                        }
                    }
                }
            })

            socket?.connect()
        }
        

    }
    
    
}
