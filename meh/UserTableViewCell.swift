//
//  UserTableViewCell.swift
//  meh
//
//  Created by Tina Quach on 4/28/17.
//  Copyright © 2017 6.S062 Group. All rights reserved.
//

import UIKit

class UserTableViewCell: UITableViewCell {
    // MARK: Properties
    
    @IBOutlet weak var usernameLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // initialize the cell with username
    }
    override func setSelected(_ selected:Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        // config the view for the selected state
    }
}


