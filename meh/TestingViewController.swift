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
    let DATA_FILE_NAME = "log.csv"
    var logFile:FileHandle? = nil
    
    var logs = [String: LogEntry]() // username: log entry
    let hopCounts = MessengerModel.getHopCounts(metadata: MessengerModel.shared.metadata)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        
        let hopCounts = MessengerModel.getHopCounts(metadata: MessengerModel.shared.metadata)
        
        for (username, hops) in hopCounts {
            let logEntry = LogEntry(recipient: username, hops: hops, pingsSent: 0, acks: 0, avgLatency: nil)
            logs[username] = logEntry
            
        }
        // battery logging setup
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        // log file setup
        self.logFile = self.openFileForWriting()
        if self.logFile == nil {
            assert(false, "Couldn't open file for writing (" + self.getPathToLogFile() + ").")
        }
        self.logLineToDataFile("recipient,hops,pingsSent,acks,avgLatency,batteryLevel\n")
        
        // Set this view controller to be the delegate of MessengerModel that keeps track of the messages being sent between you and others on the network.
        MessengerModel.shared.delegates.append(self)
        testDirectPeers()

    }
    
    
    func getPathToLogFile() -> String {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let filePath = documentsPath + "/" + DATA_FILE_NAME
        return filePath
    }
    
    func openFileForWriting() -> FileHandle? {
        let fileManager = FileManager.default
        let created = fileManager.createFile(atPath: self.getPathToLogFile(), contents: nil, attributes: nil)
        if !created {
            assert(false, "Failed to create file at " + self.getPathToLogFile() + ".")
        }
        return FileHandle(forWritingAtPath: self.getPathToLogFile())
    }
    
    func logLineToDataFile(_ line: String) {
        self.logFile?.write(line.data(using: String.Encoding.utf8)!)
        print(line)
    }
    
    func resetLogFile() {
        self.logFile?.closeFile()
        self.logFile = self.openFileForWriting()
        if self.logFile == nil {
            assert(false, "Couldn't open file for writing (" + self.getPathToLogFile() + ").")
        }
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
    
    // TODO(test inDirect peers)
    
    // MARK: MessengerModelDelegate methods
    func didSendMessage(msg: UserMessage?) {
        print("[TestingViewController] didSendMessage(msg: \(msg)")
        if msg == nil {
            return
        }
        let oldEntry = logs[msg!.recipient]
        // TODO: every time a message is sent we want to calculate and update the evaluation metrics.
        // increment # of pings sent in entry
        // set current battery level
        
        // TODO(quacht): define a new entry that replaces the old one based on this message
        logs[(msg?.recipient)!]?.pingsSent = (oldEntry?.pingsSent)! + 1

        self.logLineToDataFile("recipient,hops,pingsSent,acks,avgLatency,batteryLevel\n")
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
        let oldEntry = logs[msg.recipient]
        // average latency is
        if oldEntry == nil {
            // TODO: create a new entry if need be.
            print("UH OH! Missing entry for \(msg.recipient)...could not update entry.")
        }
        logs[msg.recipient]?.avgLatency = (oldEntry?.avgLatency*oldEntry?.acks + latency)/(oldEntry?.acks + 1)
        logs[msg.recipient]?.acks += 1
        
        // write data to csv file
        //  battery level is a float that ranges from 0 to 1.0, or is -1.0 if info not available.)
        self.logLineToDataFile("\(msg.recipient),\(logs[msg.recipient]?.hops),\(logs[msg.recipient]?.pingsSent),\(logs[msg.recipient]?.acks),\(logs[msg.recipient]?.avgLatency),\(UIDevice.current.batteryLevel)\n")

    }
}
