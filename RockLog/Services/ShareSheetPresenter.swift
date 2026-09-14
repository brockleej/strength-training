//
//  ShareSheetPresenter.swift
//  Presents UIActivityViewController from the topmost view controller.
//  Embedding ActivityView in a SwiftUI sheet nests a modal that renders blank.
//

import UIKit

enum ShareSheetPresenter {
    static func presentFile(_ url: URL, onComplete: ((Bool) -> Void)? = nil) {
        guard let root = rootViewController() else { return }

        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activity.completionWithItemsHandler = { _, completed, _, _ in
            onComplete?(completed)
        }
        if let popover = activity.popoverPresentationController {
            popover.sourceView = root.view
            popover.sourceRect = CGRect(x: root.view.bounds.midX, y: root.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        var presenter = root
        while let next = presenter.presentedViewController {
            presenter = next
        }
        presenter.present(activity, animated: true)
    }

    private static func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}
