import Foundation
import SVProgressHUD


struct ReaderPostMenuButtonTitles {
    static let cancel = NSLocalizedString("Cancel", comment: "The title of a cancel button.")
    static let blockSite = NSLocalizedString("Block This Site", comment: "The title of a button that triggers blocking a site from the user's reader.")
    static let share = NSLocalizedString("Share", comment: "Verb. Title of a button. Pressing lets the user share a post to others.")
    static let visit = NSLocalizedString("Visit", comment: "An option to visit the site to which a specific post belongs")
    static let unfollow = NSLocalizedString("Unfollow Site", comment: "Verb. An option to unfollow a site.")
    static let follow = NSLocalizedString("Follow Site", comment: "Verb. An option to follow a site.")
}


open class ReaderPostMenu {
    open static let BlockSiteNotification = "ReaderPostMenuBlockSiteNotification"

    open class func showMenuForPost(_ post: ReaderPost, fromView anchorView: UIView, inViewController viewController: UIViewController) {
        // Create the action sheet
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alertController.addCancelActionWithTitle(ReaderPostMenuButtonTitles.cancel, handler: nil)

        // Block button
        if shouldShowBlockSiteMenuItemForPost(post) {
            alertController.addActionWithTitle(ReaderPostMenuButtonTitles.blockSite,
                style: .destructive,
                handler: { (action: UIAlertAction) in
                    self.blockSiteForPost(post)
            })
        }

        // Following
        let buttonTitle = post.isFollowing ? ReaderPostMenuButtonTitles.unfollow : ReaderPostMenuButtonTitles.follow
        alertController.addActionWithTitle(buttonTitle,
            style: .default,
            handler: { (action: UIAlertAction) in
                self.toggleFollowingForPost(post)
        })

        // Visit site
        alertController.addActionWithTitle(ReaderPostMenuButtonTitles.visit,
            style: .default,
            handler: { (action: UIAlertAction) in
                self.visitSiteForPost(post, presentingViewController: viewController)
        })

        // Share
        alertController.addActionWithTitle(ReaderPostMenuButtonTitles.share,
            style: .default,
            handler: { (action: UIAlertAction) in
                let sharingController = PostSharingController()

                sharingController.shareReaderPost(post, fromView: anchorView, inViewController: viewController)
        })

        if UIDevice.isPad() {
            alertController.modalPresentationStyle = .popover
            viewController.present(alertController, animated: true, completion: nil)
            if let presentationController = alertController.popoverPresentationController {
                presentationController.permittedArrowDirections = .any
                presentationController.sourceView = anchorView
                presentationController.sourceRect = anchorView.bounds
            }

        } else {
            viewController.present(alertController, animated: true, completion: nil)
        }
    }


    fileprivate class func shouldShowBlockSiteMenuItemForPost(_ post: ReaderPost) -> Bool {
        if let topic = post.topic {
            if (ReaderHelpers.isLoggedIn()) {
                return ReaderHelpers.isTopicTag(topic) || ReaderHelpers.topicIsFreshlyPressed(topic)
            }
        }
        return false
    }


    fileprivate class func blockSiteForPost(_ post: ReaderPost) {
        // TODO: Dispatch notification to block the site for the specified post.
        // The list and the detail will need to handle this separately
        NotificationCenter.default.post(name: Foundation.Notification.Name(rawValue: BlockSiteNotification), object: nil, userInfo: ["post": post])
    }


    fileprivate class func toggleFollowingForPost(_ post: ReaderPost) {
        var successMessage: String!
        var errorMessage: String!
        var errorTitle: String!
        if post.isFollowing {
            successMessage = NSLocalizedString("Unfollowed site", comment: "Short confirmation that unfollowing a site was successful")
            errorTitle = NSLocalizedString("Problem Unfollowing Site", comment: "Title of a prompt")
            errorMessage = NSLocalizedString("There was a problem unfollowing the site. If the problem persists you can contact us via the Me > Help & Support screen.", comment: "Short notice that there was a problem unfollowing a site and instructions on how to notify us of the problem.")
        } else {
            successMessage = NSLocalizedString("Followed site", comment: "Short confirmation that following a site was successful")
            errorTitle = NSLocalizedString("Problem Following Site", comment: "Title of a prompt")
            errorMessage = NSLocalizedString("There was a problem following the site.  If the problem persists you can contact us via the Me > Help & Support screen.", comment: "Short notice that there was a problem following a site and instructions on how to notify us of the problem.")

            WPNotificationFeedbackGenerator.notificationOccurred(.success)
        }

        SVProgressHUD.show()

        let postService = ReaderPostService(managedObjectContext: post.managedObjectContext!)
        postService.toggleFollowing(for: post, success: { () in
            SVProgressHUD.showSuccess(withStatus: successMessage)
            }, failure: { (error: Error?) in
                SVProgressHUD.dismiss()

                WPNotificationFeedbackGenerator.notificationOccurred(.error)

                let cancelTitle = NSLocalizedString("OK", comment: "Text of an OK button to dismiss a prompt.")
                let alertController = UIAlertController(title: errorTitle,
                    message: errorMessage,
                    preferredStyle: .alert)
                alertController.addCancelActionWithTitle(cancelTitle, handler: nil)
                alertController.presentFromRootViewController()
        })
    }


    fileprivate class func visitSiteForPost(_ post: ReaderPost, presentingViewController viewController: UIViewController) {
        guard
            let permalink = post.permaLink,
            let siteURL = URL(string: permalink) else {
                return
        }

        let controller = WPWebViewController(url: siteURL)
        controller?.addsWPComReferrer = true
        let navController = UINavigationController(rootViewController: controller!)
        viewController.present(navController, animated: true, completion: nil)
    }
}
