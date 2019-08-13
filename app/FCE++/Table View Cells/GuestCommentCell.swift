//
//  GuestCommentTableViewCell.swift
//  FCE++
//
//  Created by Sam Flattery on 6/21/19.
//  Copyright © 2019 Sam Flattery. All rights reserved.
//

import UIKit

protocol GuestCommentCellDelegate {
    func showLoginScreen()
}

class GuestCommentCell: UITableViewCell {
    
    var delegate: GuestCommentCellDelegate!
    @IBOutlet weak var loginButton: UIButton!
    
    @IBAction func loginPressed(_ sender: Any) {
        delegate.showLoginScreen()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()

    }

}
