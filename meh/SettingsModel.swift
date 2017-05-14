//
//  SettingsModel.swift
//  Anteater
//
//  Created by Justin Anderson on 1/30/17.
//  Copyright © 2017 MIT. All rights reserved.
//

import Foundation

class SettingsModel {
    
    enum DefaultsKey: String {
        case Username = "Me$HUsernameKey"
    }
    
    static var username: String? { // name to post new readings under
        get {
            print("User selected username \(String(describing: UserDefaults.standard.string(forKey: DefaultsKey.Username.rawValue)))")
            return UserDefaults.standard.string(forKey: DefaultsKey.Username.rawValue)
        }
        set(newUsername) {
            print("Setting username to \(String(describing: newUsername))")
            UserDefaults.standard.set(newUsername, forKey: DefaultsKey.Username.rawValue)
        }
    }

}
