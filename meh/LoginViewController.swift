//
//  LoginViewController.swift
//  meh
//
//  Created by Tina Quach on 4/28/17.
//  Copyright © 2017 6.S062 Group. All rights reserved.
//

import UIKit

class LoginViewController: UIViewController {
    
    // MARK: Properties

    @IBOutlet weak var usernameField: UITextField!
    @IBOutlet weak var connectButton: UIButton!

    @IBAction func connectToMeshNetwork(sender: UIButton) {
        registerUsername()
        joinMeshNetwork()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("login view loaded")
        // Do any additional setup after loading the view, typically from a nib.

    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        registerUsername()
        return true
    }
    
    func registerUsername() {
        guard let username = usernameField?.text else {
            return
        }
        if username.characters.count < 3 {
            let alert = UIAlertController(
                title: "Invalid Username",
                message: "Please enter a username that is at least 3 characters.",
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
            return
        }
        guard (UIDevice.current.identifierForVendor?.uuidString) != nil else {
            return
        }
        
        // Store new user's username
        SettingsModel.username = username
                self.dismiss(animated: true, completion: { _ in })
        print("registered username")
    }
    
    func joinMeshNetwork() {
        print("attemping to scanning for others in network")
        if (MessengerModel.shared.ble?.startScanning(timeout: MessengerModel.kBLE_SCAN_TIMEOUT))! {
            print("started scanning for node through which to join network")
        } else {
            print("unable to start scanning")
        }
    }


    
    
}
