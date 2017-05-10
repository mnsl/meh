//
//  UserListViewController.swift
//  meh
//
//  Created by Tina Quach on 4/30/17.
//  Copyright © 2017 6.S062 Group. All rights reserved.
//

import Foundation
import UIKit

// TODO: Set this view controller to be the delegate of some model that keeps track of who is on the network, and who you already know.
class UserListViewController: UIViewController, UITableViewDataSource, MessengerModelDelegate, UITableViewDelegate {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var startchat: UIButton!
    
    var onlineUsers = MessengerModel.shared.users
    public static var onlineUsersArray: Array<User> = []
    // TODO(quacht): pull onlineUsers from the messenger model
    public static var selectedUsers: Set = Set<User>()
    
    // MARK: - UITableViewDataSource
    
    // TODO: could add this in order to section off the user list into available now, and known but unavailable.
    
    @IBAction func startChatButtonClick(_ sender: Any) {
        print("starting chat with ")
        print(UserListViewController.selectedUsers)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsMultipleSelection = true
        tableView.beginUpdates()

        // NOTE: in the beginning, onlineUsers is nil, because we have not been able to identify any users nearby.
        if UserListViewController.onlineUsersArray.count == 0 {
        print("no online users")
        } else {
        for i in 0...(UserListViewController.onlineUsersArray.count-1) {
            var name = UserListViewController.onlineUsersArray[i].name
            if name == nil {
                name = UserListViewController.onlineUsersArray[i].uuid.uuidString
            }
            addUsername(username: name!)
        }

        }
        tableView.endUpdates()
    }
    
    func addUsername(username:String) {
        let cell_to_fill = tableView.dequeueReusableCell(withIdentifier: "Username")
        print("cell_to_fill")
        print(cell_to_fill!)
        cell_to_fill?.textLabel?.text = username
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return UserListViewController.onlineUsersArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "UITableViewCell", for: indexPath)
        
        cell.accessoryType = cell.isSelected ? .checkmark : .none
        //        cell.selectionStyle = .none // to prevent cells from being "highlighted"
        print(UserListViewController.onlineUsersArray[indexPath.row].name)
        cell.textLabel?.text = UserListViewController.onlineUsersArray[indexPath.row].name
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
        // let selectedUser = tableView.cellForRow(at: indexPath as IndexPath)?.textLabel?.text;
        let selectedUser = UserListViewController.onlineUsersArray[indexPath.row]
        UserListViewController.selectedUsers.insert(selectedUser);
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        tableView.cellForRow(at: indexPath)?.accessoryType = .none
//        let deselectedUser = tableView.cellForRow(at: indexPath as IndexPath)?.textLabel?.text;
        let deselectedUser = UserListViewController.onlineUsersArray[indexPath.row];
        UserListViewController.selectedUsers.remove(deselectedUser);
    }
    
    // MARK: MessengerModelDelegate functions
    func didSendMessage(_ model: MessengerModel, msg: Message?) {
        // TODO
    }
    
    func didReceiveMessage(_ model: MessengerModel, msg: Message?) {
        // TODO
    }

    func didAddConnectedUser(_ model: MessengerModel, user: UUID) {
        UserListViewController.onlineUsersArray = Array(MessengerModel.shared.users.values)
        tableView.beginUpdates()
        if MessengerModel.shared.users[user] != nil {
            let user = MessengerModel.shared.users[user]
            addUsername(username: (user?.name)!)
    } else {
        addUsername(username: (user.uuidString))
    }
        tableView.endUpdates()
    }
    
    func didDisconnectFromUser(_ model: MessengerModel, user: UUID) {
        // TODO
    }
    
    
}
