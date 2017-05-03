//
//  UserTableViewController.swift
//  meh
//
//  Created by Tina Quach on 4/30/17.
//  Copyright © 2017 6.S062 Group. All rights reserved.
//

import Foundation
import UIKit

// TODO: Set this view controller to be the delegate of some model that keeps track of who is on the network, and who you already know.
class UserlistTableViewController: UITableViewController {
    
    var onlineUsers = ["keam", "mnsl", "quacht", "mnsl", "quacht", "mnsl", "quacht", "mnsl", "quacht"];
    var selectedUsers: Set = Set<String>()
    
    // MARK: - UITableViewDataSource
    
    // TODO: could add this in order to section off the user list into available now, and known but unavailable.

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.allowsMultipleSelection = true
        // Add a footer for the submission button
        var tableViewFooter = UIView(frame: CGRect(x: 0, y: 0, width: 600, height: 50))
        let button = UIButton(frame: CGRect(x: 100, y: 400, width: 100, height: 50))
        button.backgroundColor = .black
        button.setTitle("Start Chat!", for: .normal)
        button.addTarget(self, action:#selector(startChat), for: .touchUpInside)
        self.tableView.addSubview(button)
        
        func buttonClicked() {
            print("Button Clicked")
        }
        tableView.tableFooterView  = tableViewFooter
    }
//
    func startChat() {
        print("starting chat with ")
        print(selectedUsers)
    }
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return onlineUsers.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "UITableViewCell", for: indexPath)
        
        cell.accessoryType = cell.isSelected ? .checkmark : .none
//        cell.selectionStyle = .none // to prevent cells from being "highlighted"
        cell.textLabel?.text = onlineUsers[indexPath.row]
        
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
        let selectedUser = tableView.cellForRow(at: indexPath as IndexPath)?.textLabel?.text;
        selectedUsers.insert(selectedUser!);
    }
    
    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        tableView.cellForRow(at: indexPath)?.accessoryType = .none
        let deselectedUser = tableView.cellForRow(at: indexPath as IndexPath)?.textLabel?.text;
        selectedUsers.remove(deselectedUser!);
    }

//    let customView = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
//    customView.backgroundColor = UIColor.red
//    let button = UIButton(frame: CGRect(x: 0, y: 0, width: 100, height: 50))
//    button.setTitle("Submit", for: .normal)
//    button.addTarget(self, action: #selector(buttonAction), for: .touchUpInside)
//    customView.addSubview(button)
    
}
