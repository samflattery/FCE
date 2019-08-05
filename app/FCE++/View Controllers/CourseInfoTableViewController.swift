//
//  CourseInfoTableViewController.swift
//  FCE++
//
//  Created by Sam Flattery on 6/7/19.
//  Copyright © 2019 Sam Flattery. All rights reserved.
//

import UIKit
import Parse
import SVProgressHUD

typealias CourseComments = [[String: Any]] // comments are stored as a list of dictionaries
typealias CourseComment = [String: Any]

class CourseInfoTableViewController: UITableViewController, UITextFieldDelegate, NewCommentCellDelegate, GuestCommentCellDelegate {

    var query: PFQuery<PFObject>? // the currently active comment query
    var reachability: Reachability! // the user's internet status
    
    var course: Course!  // the course being displayed
    var instructorInfo = [[String]]()  // the instructors json in the form of an array
                                         // for table indexing
    var courseInfo: [String]!  // as above but with the course information
    
    var courseComments: CourseComments?  // the list of comments to be displayed,
                                         // can be nil if unable to load
    var commentObj: PFObject?  // the comments as an object to be passed to the newComment cell
    
    var hasDownloadedComments = false // have the comments already been loaded in the background?
    var failedToLoad = false  // the user has no internet, show them the failed to load cell
    var isLoadingNewComment = false  // if the user posts a new comment, show loading cell
    
    var isEditingComment = false  // if the user is editing a comment, show the new comment cell
    var editingIndex : Int!
    var isLoadingEditedComment = false
    
    var cellHeights: [IndexPath : CGFloat] = [:] // a dictionary of cell heights to avoid jumpy table
    
    @IBOutlet weak var segmentControl: UISegmentedControl!
    let refreshController = UIRefreshControl()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        registerNibs()
        self.hideKeyboardWhenTappedAround()
        extendedLayoutIncludesOpaqueBars = true
        
        self.failedToLoad = false
        self.hasDownloadedComments = false
        tableView.estimatedRowHeight = 60
    
        // get info as lists instead of dictionaries
        courseInfo = getCourseData(course)
        for instructor in course.instructors {
            instructorInfo.append(getInstructorData(instructor))
        }
    }
    
    func registerNibs() {
        //Register all of the cell nibs
        var cellNib = UINib(nibName: "NewComment", bundle: nil)
        tableView.register(cellNib, forCellReuseIdentifier: "NewComment")
        
        cellNib = UINib(nibName: "CommentCell", bundle: nil)
        tableView.register(cellNib, forCellReuseIdentifier: "CommentCell")
        
        cellNib = UINib(nibName: "GuestComment", bundle: nil)
        tableView.register(cellNib, forCellReuseIdentifier: "GuestComment")
        
        cellNib = UINib(nibName: "FailedToLoad", bundle: nil)
        tableView.register(cellNib, forCellReuseIdentifier: "FailedToLoad")
        
        cellNib = UINib(nibName: "LoadingCell", bundle: nil)
        tableView.register(cellNib, forCellReuseIdentifier: "LoadingCell")
        
        cellNib = UINib(nibName: "CourseInfoCell", bundle: nil)
        tableView.register(cellNib, forCellReuseIdentifier: "CourseInfoCell")
        
        cellNib = UINib(nibName: "NewCommentCell", bundle: nil)
        tableView.register(cellNib, forCellReuseIdentifier: "NewCommentCell")
    }
    
    @IBAction func segmentControlValueChanged(_ sender: Any) {
        SVProgressHUD.dismiss() // if the user leaves comments when loading, dismiss
        tableView.refreshControl = nil // remove the pull to refresh
        if segmentControl.selectedSegmentIndex == 2 { // comments segment
            tableView.refreshControl = refreshController
            refreshControl?.addTarget(self, action: #selector(refreshComments), for: .valueChanged)
            if !hasDownloadedComments {
                query = PFQuery(className:"Comments")
                query!.whereKey("courseNumber", equalTo: course.number)
                
                reachability = Reachability()!
                if reachability.connection == .none && !query!.hasCachedResult {
                    tableView.reloadData()
                    failedToLoad = true
                    SVProgressHUD.showError(withStatus: "No internet connection")
                    SVProgressHUD.dismiss(withDelay: 1)
                    courseComments = nil
                    commentObj = nil
                    return
                }
                SVProgressHUD.show()
                
                tableView.reloadData()
                query!.cachePolicy = .networkElseCache // first try network to get up to date, then cache
                query!.findObjectsInBackground { (objects: [PFObject]?, error: Error?) in
                    if let error = error {
                        // failed to get comments for some reason
                        SVProgressHUD.dismiss()
                        self.courseComments = nil
                        self.commentObj = nil
                        SVProgressHUD.showError(withStatus: "Failed to load comments.")
                        SVProgressHUD.dismiss(withDelay: 1)
                        print("failed in segment value changed", error.localizedDescription)
                    } else if let objects = objects {
                        // found objects
                        self.hasDownloadedComments = true
                        let object = objects[0] // should only return one object
                        self.courseComments = (object["comments"] as! CourseComments)
                        self.commentObj = object
                        SVProgressHUD.dismiss()
                        self.tableView.reloadData()
                    }
                }
            } else {
                tableView.reloadData() // if the comments are already loaded, just reload table
            }
        } else {
            tableView.reloadData() // if it isn't the comment segment, just reload table
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowReplies" {
            let controller = segue.destination as! CommentRepliesViewController
            controller.commentObj = commentObj
            let commentIndex = sender as! Int
            controller.commentIndex = commentIndex
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // cancel any queries running in background and dismiss any progress huds
        query?.cancel()
        SVProgressHUD.dismiss()
    }
    
    @objc func refreshComments() { // needs to be objc for the refreshControl
        // called when post clicked or when pulled to refresh
        reachability = Reachability()!
        if reachability.connection == .none {
            if let rC = self.refreshControl {
                // if there's no internet but there is a refresh bar, end the refreshing
                rC.endRefreshing()
            }
            return
        }
        self.commentObj?.fetchInBackground(block: { (object: PFObject?, error: Error?) in
            // fetch new comments in the background and update the comment array
            self.courseComments = (object?["comments"] as! CourseComments)
            self.refreshControl?.endRefreshing()
            if self.isLoadingNewComment {
                self.isLoadingNewComment = false
            }
            self.tableView.reloadData()
        })
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if segmentControl.selectedSegmentIndex == 2 {
            if PFUser.current() == nil && indexPath.section == 0 {
                // take the guest back to login screen
                showLoginScreen()
            } else if PFUser.current() != nil && indexPath.section == 0 {
                return
            } else {
                if isEditingComment {
                    // can't segue to the comment that is being edited
                    if editingIndex == indexPath.row {
                        return
                    }
                }
                performSegue(withIdentifier: "ShowReplies", sender: indexPath.row)
            }
        }
    }

    //MARK: - TableViewDelegates
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // save the height of each cell in the dictionary for faster calculations
        // makes the table transitions smoother
        cellHeights[indexPath] = cell.frame.size.height
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return cellHeights[indexPath] ?? 70.0
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        if segmentControl.selectedSegmentIndex == 1 {
            // one segment for each instructor
            return instructorInfo.count
        } else if segmentControl.selectedSegmentIndex == 2 {
            return 2
        } else {
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if segmentControl.selectedSegmentIndex == 0 {
            return 1
        } else if segmentControl.selectedSegmentIndex == 1 {
            return 11 // one for each piece of instructor info
        } else {
            if section == 0 {
                return 1
            } else {
                if let comments = courseComments {
                    return isLoadingNewComment ? comments.count + 1 : comments.count
                } else { // there were no comments to show so just show failed to load cell
                    return 1
                }
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if segmentControl.selectedSegmentIndex == 1 {
            return instructorInfo[section][0]
        } else if segmentControl.selectedSegmentIndex == 2 && section == 0 {
            return "New Comment"
        }
        return nil
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if segmentControl.selectedSegmentIndex == 2 && indexPath.section == 1 {
            if courseComments == nil || PFUser.current() == nil {
                return false
            } else if (courseComments?[indexPath.row]["andrewID"] as! String) == PFUser.current()?.username {
                return true
            }
        }
        return false
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        var editActions : [UITableViewRowAction]? = nil
        if segmentControl.selectedSegmentIndex == 2 && indexPath.section == 1 {
            if (courseComments?[indexPath.row]["andrewID"] as! String) == PFUser.current()?.username {
                let deleteAction = UITableViewRowAction(style: .destructive, title: "Delete") { (action, indexPath) in
                    let comments = self.courseComments![indexPath.row]["replies"] as! [String : Any]
                    let numReplies = comments.count
                    var alertMessage = ""
                    if numReplies == 0 {
                        alertMessage = "Are you sure you want to delete this comment?"
                    } else {
                        alertMessage = "This comment has \(numReplies) replies that other students may find useful! Consider making the comment anonymous!"
                    }
        
                    let alert = UIAlertController(title: "Are you sure?", message: alertMessage, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { _ in
                        //Cancel Action
                    }))
                    alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { (_) in
                        // delete the comment and refresh the table
                    }))
 
                    self.present(alert, animated: true, completion: nil)
                }
                let editAction = UITableViewRowAction(style: .normal, title: "Edit") { (action, indexPath) in
                    if self.isEditingComment {
                        self.isEditingComment = false
                        self.tableView.reloadRows(at: [IndexPath(item: self.editingIndex, section: 1)], with: .fade)
                        self.editingIndex = nil
                    }
                    self.isEditingComment = true
                    self.editingIndex = indexPath.row
                    self.tableView.reloadRows(at: [indexPath], with: .bottom)
                    self.tableView.scrollToRow(at: indexPath, at: .none, animated: true)
                }
                editActions = [deleteAction, editAction]
            }
        }
        return editActions
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let i = indexPath.row
        let j = indexPath.section
        
        if failedToLoad && segmentControl.selectedSegmentIndex == 2 {
            // only display the failed to load cell
            let failedToLoadCell = tableView.dequeueReusableCell(withIdentifier: "FailedToLoad", for: indexPath)
            return failedToLoadCell
        }

        if segmentControl.selectedSegmentIndex == 0 {
            // the course information segment's cells
            let infoCell = tableView.dequeueReusableCell(withIdentifier: "CourseInfoCell", for: indexPath) as! CourseInfoTableViewCell
            infoCell.numberLabel.text = course.number
            infoCell.nameLabel.text = course.name ?? "No name available"
            if let units = course.units {
                infoCell.unitsLabel.text = "Units: \(String(format: "%.1f", units))"
            } else {
                infoCell.unitsLabel.text = "Units not available"
            }
            infoCell.hoursDetailsLabel.text = String(format: "%.1f", course.hours)
            infoCell.courseRateDetailsLabel.text = String(format: "%.1f", course.rate)
            infoCell.descriptionLabel.text = course.desc ?? "No description available"
            infoCell.prereqsDetailsLabel.text = course.prereqs ?? "None"
            infoCell.coreqDetailsLabel.text = course.coreqs ?? "None"

            return infoCell
        }
        else if segmentControl.selectedSegmentIndex == 1 {
            // the instructor segment's cells
            let instructorCell = tableView.dequeueReusableCell(withIdentifier: "InfoCell", for: indexPath) as! InfoCell
            instructorCell.headingLabel!.text = instructorTitles[i] // title of instructor field
            instructorCell.bodyLabel!.text = instructorInfo[j][i] // the instructor info
            return instructorCell
        }
        else {
            if j == 0 { // the first segment is the new comment segment
                if PFUser.current() != nil {
                    // show the new comment cell as the first cell
                    let newCommentCell = tableView.dequeueReusableCell(withIdentifier: "NewCommentCell", for: indexPath) as! NewCommentTableViewCell
                    newCommentCell.delegate = self
                    newCommentCell.courseNumber = course.number
                    newCommentCell.setupText()
                    return newCommentCell
                } else {
                    let guestCommentCell = tableView.dequeueReusableCell(withIdentifier: "GuestComment", for: indexPath) as! GuestCommentCell
                    guestCommentCell.delegate = self
                    return guestCommentCell
                }
            }
            else {
                if (i == 0 && isLoadingNewComment) || (isLoadingEditedComment && i == editingIndex) {
                    // if the user posted a new comment, display the loading cell
                    let loadingCell = tableView.dequeueReusableCell(withIdentifier: "LoadingCell", for: indexPath) as! LoadingCell
                    loadingCell.spinner.startAnimating()
                    return loadingCell
                }
                if isEditingComment && i == editingIndex {
                    let editingCell = tableView.dequeueReusableCell(withIdentifier: "NewCommentCell", for: indexPath) as! NewCommentTableViewCell
                    editingCell.delegate = self
                    editingCell.isEditingComment = true
                    editingCell.editingCommentIndex = i
                    editingCell.titleField.becomeFirstResponder()
                    editingCell.courseNumber = course.number
                    editingCell.commentText = courseComments![i]["commentText"] as? String
                    editingCell.commentTitle = courseComments![i]["header"] as? String
                    editingCell.wasAnonymous = courseComments![i]["anonymous"] as? Bool
                    editingCell.setupText()
                    return editingCell
                }
                else {
                    // display comments
                    // if the user has just posted a comment, there is a temporary cell with a loading
                    // spinner, so in this case each cell must be shifted forward by one to fit this
                    let indexRow = isLoadingNewComment ? indexPath.row - 1 : indexPath.row
                    let commentCell = tableView.dequeueReusableCell(withIdentifier: "CommentCell", for: indexPath) as! CommentCell
                    if let commentInfo = courseComments?[indexRow] {
                        commentCell.headerLabel.text = commentInfo["header"] as? String
                        commentCell.commentLabel.text = commentInfo["commentText"] as? String
                        commentCell.dateLabel.text = commentInfo["timePosted"] as? String
                        if commentInfo["anonymous"] as! Bool {
                            commentCell.andrewIDLabel.text = "Anonymous"
                        } else {
                            commentCell.andrewIDLabel.text = commentInfo["andrewID"] as? String
                        }
                    }
                    return commentCell
                }
            }
        }
    } // end of cellForIndexAt
    
    //MARK:- NewCommentCellDelegate
    func didPostComment(withData data: [String : Any], wasEdited edited: Bool, atIndex index : Int) {
        if !edited {
            isLoadingNewComment = true
            tableView.reloadData() // display loading cell
        } else {
            // loading cell for updated comment?
        }
        commentObj?.fetchInBackground { (object: PFObject?, error: Error?) in
            // have to fetch in case someone made a new comment in the meantime
            if let object = object { // if it succeeds to fetch any updates
                var comments = object["comments"] as! [[String : Any]] // the current comments
                // insert the new comment at the beginning and rewrite the old comments
                if !edited {
                    // if it's a new comment, insert the new comment at the beginning
                    comments.insert(data, at: 0)
                    object["comments"] = comments
                } else {
                    // else just rewrite the old comment at the right index
                    comments[index] = data
                    object["comments"] = comments
                }
                
                object.saveInBackground(block: { (success: Bool, error: Error?) in
                    self.isLoadingNewComment = false // remove the loading cell
                    
                    if success {
                        // update the courseComments with the new comments
                        self.courseComments = (object["comments"] as! CourseComments)
                        if edited {
                            self.isEditingComment = false
                            self.tableView.reloadRows(at: [IndexPath(item: self.editingIndex, section: 1)], with: .fade)
                            self.editingIndex = nil
                        } else {
                            self.tableView.reloadData()
                        }
                    } else if let error = error {
                        SVProgressHUD.showError(withStatus: error.localizedDescription)
                        SVProgressHUD.dismiss(withDelay: 1)
                    } else {
                        SVProgressHUD.showError(withStatus: "Something went wrong")
                        SVProgressHUD.dismiss(withDelay: 1)
                    }
                })
            } else if let error = error {
                SVProgressHUD.showError(withStatus: error.localizedDescription)
                SVProgressHUD.dismiss(withDelay: 1.5)
            } else {
                SVProgressHUD.showError(withStatus: "Something went wrong")
                SVProgressHUD.dismiss(withDelay: 1)
            }
        }
    }
    
    func didCancelComment(atIndex index : Int) {
        self.isEditingComment = false
        self.tableView.reloadRows(at: [IndexPath(item: self.editingIndex, section: 1)], with: .fade)
        self.editingIndex = nil
    }
    
    //MARK:- GuestCommentCellDelegate
    func showLoginScreen() {
        // called when the guest pressed 'login to comment'
        // instantiate a new signupscreen and push it to navigation stack
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "SignUpScreen") as! SignUpViewController
        vc.hasComeFromGuest = true
        navigationController?.pushViewController(vc, animated: true)
    }
    
} // end of class

class CommentCell: UITableViewCell { // the cell that displays a comment
    
    @IBOutlet weak var headerLabel: UILabel!
    @IBOutlet weak var commentLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var andrewIDLabel: UILabel!
    
}

class InfoCell: UITableViewCell {
    
    @IBOutlet weak var headingLabel: UILabel!
    @IBOutlet weak var bodyLabel: UILabel!
    
}
