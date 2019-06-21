//
//  NewCommentTableViewCell.swift
//  FCE++
//
//  Created by Sam Flattery on 6/11/19.
//  Copyright © 2019 Sam Flattery. All rights reserved.
//

import UIKit
import Parse
import SVProgressHUD

protocol NewReplyTableViewCellDelegate {
    func didPostReply(withData data: [String: Any])
}

class NewReplyTableViewCell: UITableViewCell, UITextViewDelegate {
    
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var postButton: UIButton!
    @IBOutlet weak var anonymousSwitch: UISwitch!
    @IBOutlet weak var anonymousLabel: UILabel!
    
    var delegate: NewReplyTableViewCellDelegate!

    var reachability: Reachability!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        textView.delegate = self
        textView.text = "Leave a reply!"
        textView.textColor = .lightGray
        
        postButton.isHidden = true
        anonymousSwitch.isHidden = true
        anonymousLabel.isHidden = true
        
        // resize the switch to make it smaller
        let switchResizeRatio: CGFloat = 0.75
        anonymousSwitch.transform = CGAffineTransform(scaleX: switchResizeRatio, y: switchResizeRatio)
        
        // limit the area of the text view where text can go to fit button and switch
        let buttonHeight: CGFloat = 44
        let switchHeight: CGFloat = 31 * switchResizeRatio
        let contentInset: CGFloat = 8
        textView.textContainerInset = UIEdgeInsets(top: contentInset, left: contentInset, bottom: switchHeight + (contentInset*2), right: buttonHeight + (contentInset*2))
    }
    
    @IBAction func postButtonPressed(_ sender: Any) {
        reachability = Reachability()!
        
        if reachability.connection == .none {
            SVProgressHUD.showError(withStatus: "No internet connection")
            SVProgressHUD.dismiss(withDelay: 1.5)
            return
        }
        
        // get the date and time of posting in a readable format
        let currentDateTime = Date()
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .medium
        let timePosted = formatter.string(from: currentDateTime)
        
        let user = PFUser.current()! // there will always be a user if this cell is active
        
        // format the comment data as it is in the database
        let replyData = ["replyText": textView.text!,
                         "timePosted": timePosted,
                         "andrewID": user.username!,
                         "anonymous": anonymousSwitch.isOn] as [String : Any] //to append to replies
        
        delegate.didPostReply(withData: replyData)
        
        // reset the text view to its default
        textView.resignFirstResponder()
        textView.text = "Leave a reply!"
        textView.textColor = .lightGray
        postButton.isHidden = true
        
    }

    //MARK:- Text Field Delegates
    func textViewDidChange(_ textView: UITextView) {
        // toggle the switches when the text view is empty or not
        if textView.text != "" {
            postButton.isHidden = false
            anonymousSwitch.isHidden = false
            anonymousLabel.isHidden = false
        } else {
            postButton.isHidden = true
            anonymousSwitch.isHidden = true
            anonymousLabel.isHidden = true
        }
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        // remove the default text
        if textView.text == "Leave a reply!" && textView.textColor == .lightGray {
            textView.text = ""
            textView.textColor = .black
        }
        textView.becomeFirstResponder()
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        // put back the default text
        postButton.isHidden = true
        anonymousSwitch.isHidden = true
        anonymousLabel.isHidden = true
        if textView.text == "" {
            textView.text = "Leave a reply!"
            textView.textColor = .lightGray
        }
        textView.resignFirstResponder()
    }

}