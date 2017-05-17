//
//  UserListViewController.swift
//  meh
//
//  Created by Tina Quach on 4/30/17.
//  Copyright © 2017 6.S062 Group. All rights reserved.
//

import Foundation
import UIKit

class UserListViewController: UIViewController, UITableViewDataSource, MessengerModelDelegate, UITableViewDelegate {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var startchat: UIButton!
    
    @IBOutlet weak var launchTests: UIButton!
    
    var onlineUsers = MessengerModel.shared.users
    public static var onlineUsersArray: Array<User> = []
    public static var selectedUser: User? = nil
    var selectedIndex : IndexPath? = nil
    
    // MARK: - UITableViewDataSource
    
    // TODO: could add this in order to section off the user list into available now, and known but unavailable.
    
    @IBAction func startChatButtonClick(_ sender: Any) {
        if UserListViewController.selectedUser != nil {
            print("[UserListViewController] starting chat with \(UserListViewController.selectedUser)")
        } else {
            print("[UserListViewController] has no user selected!")
        }
    }
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsMultipleSelection = true
        
        // Set this view controller to be the delegate of some model that keeps track of who is on the network, and who you already know.
        MessengerModel.shared.delegates.append(self)

        // NOTE: in the beginning, onlineUsers is nil, because we have not been able to identify any users nearby.
        UserListViewController.onlineUsersArray = Array(MessengerModel.shared.users.values)
        tableView.reloadData()
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return UserListViewController.onlineUsersArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "UITableViewCell", for: indexPath)
        cell.selectionStyle = .none // to prevent cells from being "highlighted"
        print("selected user \(UserListViewController.onlineUsersArray[indexPath.row].name)")
        let username = UserListViewController.onlineUsersArray[indexPath.row].name
        print("current self metadata: \(MessengerModel.shared.metadata)")
        let hopCounts = MessengerModel.getHopCounts(metadata: MessengerModel.shared.metadata)
        print("[UserListViewController] hopCounts: \(hopCounts)")
        if hopCounts[username] == nil {
            cell.textLabel?.text = username + " (not reachable)"
        } else if hopCounts[username]! == 1 {
            cell.textLabel?.text = username + " (\(hopCounts[username]!) hop)"
        } else {
            cell.textLabel?.text = username + " (\(hopCounts[username]!) hops)"
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
        
        let endIndex = UserListViewController.onlineUsersArray.count - 1
        for i in 0...endIndex {
            if i != indexPath.row {
                tableView.cellForRow(at: IndexPath(row: i, section: 0))?.accessoryType = .none
            }
        }
        
        let selectedUser = UserListViewController.onlineUsersArray[indexPath.row]
        UserListViewController.selectedUser = selectedUser
        if selectedIndex != nil {
            tableView.cellForRow(at: selectedIndex!)?.accessoryType = .none
        }
        selectedIndex = indexPath
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        tableView.cellForRow(at: indexPath)?.accessoryType = .none
        UserListViewController.selectedUser = nil
        selectedIndex = nil
    }
    
    // TODO(quacht): if didRecieveMessage goes provides visual indication of a message being received, also turn off that
    // indication once a message has been checked.
    
    // MARK: MessengerModelDelegate functions
    func didSendMessage(msg: UserMessage?) {
        // Nothing
        return
    }
    
    func didReceiveMessage(msg: UserMessage?) {
        // TODO: bold the text of the user in the userlist
        // Maintain state of what messages have been unread?
        return
    }

    func didUpdateUsers() {
        print("[UserListViewController] updated users")
        UserListViewController.onlineUsersArray = Array(MessengerModel.shared.users.values)
        tableView.reloadData()
    }
    
    func didReceiveAck(for msg: UserMessage, latency: TimeInterval) {
        // Do nothing 
        return
    }
    
    
}
