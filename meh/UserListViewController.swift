//
//  UserListViewController.swift
//  meh
//
//  Created by Tina Quach on 4/30/17.
//  Copyright © 2017 6.S062 Group. All rights reserved.
//

import Foundation
import UIKit

struct UserEntry : Hashable {
    let user : User
    var unreadMessages : Bool
    var hopCount : Int?
    
    // conform to Hashable protocol
    var hashValue: Int {
        return "\(user),\(unreadMessages),\(hopCount)".hashValue
    }
    
    static func == (lhs: UserEntry, rhs: UserEntry) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}

class UserListViewController: UIViewController, UITableViewDataSource, MessengerModelDelegate, UITableViewDelegate {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var startchat: UIButton!
    
    @IBOutlet weak var launchTests: UIButton!
    
    var onlineUsers = MessengerModel.shared.users
    public static var onlineUsersArray: Array<User> = []
    public static var selectedUser: User? = nil
    var selectedIndex : IndexPath? = nil
    
    public static var userEntries = [String: UserEntry]() // username : UserEntry
    
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
    
    func userEntryToString(userEntry : UserEntry) -> String {
        var str = ""
        if userEntry.unreadMessages {
            str = "✉️ "
        } else {
            str = "   "
        }
        
        str += "\(userEntry.user.name) "
        
        if userEntry.hopCount == nil {
            str += "[no known path to user]"
        } else {
            str += "[\(userEntry.hopCount!) hops to user]"
        }
        return str
    }
    
    func userEntryAtIndex(indexPath: IndexPath) -> UserEntry? {
        let sortedUsernames = UserListViewController.userEntries.keys.sorted()
        if sortedUsernames.count < indexPath.row - 1 {
            print("indexPath out of range")
            return nil
        }
        let usernameForIndex = sortedUsernames[indexPath.row]
        
        if let userEntry = UserListViewController.userEntries[usernameForIndex] {
            return userEntry
        } else {
            print("no user entry for username at index \(indexPath.row)")
            return nil
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "UITableViewCell", for: indexPath)
        cell.selectionStyle = .none // to prevent cells from being "highlighted"
        
        if let userEntry = userEntryAtIndex(indexPath: indexPath) {
            cell.textLabel?.text = userEntryToString(userEntry: userEntry)
        } else {
            print("no user entry for username at index \(indexPath.row)")
            cell.textLabel?.text = "[invalid]"
        }
        return cell
        
        /*
        
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
         */
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
        
        let endIndex = UserListViewController.onlineUsersArray.count - 1
        for i in 0...endIndex {
            if i != indexPath.row {
                tableView.cellForRow(at: IndexPath(row: i, section: 0))?.accessoryType = .none
            }
        }
        UserListViewController.selectedUser = userEntryAtIndex(indexPath: indexPath)?.user
        // turn off unread message icon if there
        if UserListViewController.selectedUser == nil { return }
        let username = UserListViewController.selectedUser!.name
        if let oldEntry = UserListViewController.userEntries[username] {
            let newEntry = UserEntry(user: UserListViewController.selectedUser!, unreadMessages: false, hopCount: oldEntry.hopCount)
            UserListViewController.userEntries[username] = newEntry
            tableView.reloadData()
        }
        
        if selectedIndex != nil {
            tableView.cellForRow(at: selectedIndex!)?.accessoryType = .none
        }
        selectedIndex = indexPath
        
        
        /*
        let selectedUser = UserListViewController.onlineUsersArray[indexPath.row]
        UserListViewController.selectedUser = selectedUser
        */
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
        if msg == nil { return }
        if let oldEntry : UserEntry = UserListViewController.userEntries[msg!.origin] {
            let newEntry = UserEntry(user: oldEntry.user, unreadMessages: true, hopCount: oldEntry.hopCount)
            UserListViewController.userEntries[msg!.origin] = newEntry
        }
        tableView.reloadData()
    }

    func didUpdateUsers() {
        print("[UserListViewController] updated users")
        UserListViewController.onlineUsersArray = Array(MessengerModel.shared.users.values)
        
        let hopCounts = MessengerModel.getHopCounts(metadata: MessengerModel.shared.metadata)
        
        for (username, user) in MessengerModel.shared.users {
            let hopCount : Int? = hopCounts[username]
            if let oldEntry = UserListViewController.userEntries[username] {
                let newEntry = UserEntry(user: user, unreadMessages: oldEntry.unreadMessages, hopCount: hopCount)
                UserListViewController.userEntries[username] = newEntry
            } else {
                print("adding user \(username) to userEntries")
                let userEntry = UserEntry(user: user, unreadMessages: false, hopCount: hopCount)
                UserListViewController.userEntries[username] = userEntry
            }
        }
        /*
        for (username, hopCount) in hopCounts {
            if let user : User = MessengerModel.shared.users[username] {
                if let oldEntry = UserListViewController.userEntries[username] {
                    let newEntry = UserEntry(user: user, unreadMessages: oldEntry.unreadMessages, hopCount: hopCount)
                    UserListViewController.userEntries[username] = newEntry
                } else {
                    print("adding user \(username) to userEntries")
                    let userEntry = UserEntry(user: user, unreadMessages: false, hopCount: hopCount)
                    UserListViewController.userEntries[username] = userEntry
                }
            } else {
                print("unknown user \(username) in hopCounts...")
            }
        }
        */

        tableView.reloadData()
    }
    
    func didReceiveAck(for msg: UserMessage, latency: TimeInterval) {
        // Do nothing 
        return
    }
    
    
}
