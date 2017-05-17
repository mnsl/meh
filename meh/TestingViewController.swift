//
//  TestingViewController.swift
//  meh
//
//  Created by Jane Maunsell on 5/16/17.
//  Copyright © 2017 6.S062 Group. All rights reserved.
//

import Foundation
import UIKit

struct LogEntry {
    let recipient : String
    let hops : Int
    var pingsSent : Int
    var acks : Int
    var avgLatency : Int?
}

class TestingViewController: UIViewController, UITableViewDataSource, MessengerModelDelegate, UITableViewDelegate {
    @IBOutlet weak var tableView: UITableView!
    
    var logs = [String: LogEntry]() // username: log entry
    let hopCounts = MessengerModel.getHopCounts(metadata: MessengerModel.shared.metadata)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        
        let hopCounts = MessengerModel.getHopCounts(metadata: MessengerModel.shared.metadata)
        
        for (username, hops) in hopCounts {
            let logEntry = LogEntry(recipient: username, hops: hops, pingsSent: 0, acks: 0, avgLatency: nil)
            
        }
        
        
        // Set this view controller to be the delegate of MessengerModel that keeps track of the messages being sent between you and others on the network.
        MessengerModel.shared.delegates.append(self)
        
        testDirectPeers()

    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: UITableViewDataSource methods
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "UITableViewCell", for: indexPath)
        cell.selectionStyle = .none // to prevent cells from being "highlighted"
        let sortedUsernames = Array(self.logs.keys).sorted()
        let username = sortedUsernames[indexPath.row]
        let logEntry = self.logs[username]!
        
        cell.textLabel?.text = logEntryToString(logEntry: logEntry)
        
        return cell
    }

    func logEntryToString(logEntry: LogEntry) -> String {
        return "\(logEntry.recipient)\t\(logEntry.hops)\t\(logEntry.pingsSent)\t\(logEntry.acks)\t\(logEntry.avgLatency)"
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.logs.count
    }
    
    // MARK: Test methods
    
    func testDirectPeers() {
        if MessengerModel.shared.metadata.peerMap[SettingsModel.username!] == nil {
            print("testDirectPeers cannot run without direct peers...")
            return
        }
        for username in MessengerModel.shared.metadata.peerMap[SettingsModel.username!]! {
            for i in 0..<100 {
                MessengerModel.shared.sendMessage(message: "test", recipient: username)
            }

        }
    }
    
    // MARK: MessengerModelDelegate methods
    func didSendMessage(msg: UserMessage?) {
        print("[TestingViewController] didSendMessage(msg: \(msg)")
        if msg == nil {
            return
        }
        let oldEntry = logs[msg!.recipient]
        // TODO
    }
    
    func didReceiveMessage(msg: UserMessage?) {
        print("[TestingViewController] didReceiveMessage(msg: \(msg)")
        if msg != nil {
            
        } else {
            print("Sent message is nil! --> not going to display in chat.")
        }
    }
    
    func didUpdateUsers() {
        // Do nothing
        return
    }
    
    
    func didReceiveAck(for msg: UserMessage, latency: TimeInterval) {
        print("[TestingViewController] didReceiveAck(for: \(msg)")
    }
}
