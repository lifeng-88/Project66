import SwiftUI
import UIKit

extension View {
    @ViewBuilder
    func hidesTabBarWhenPushed() -> some View {
        if #available(iOS 16.0, *) {
            toolbar(.hidden, for: .tabBar)
        } else {
            background(TabBarVisibilitySetter(hidden: true))
        }
    }
}

private struct TabBarVisibilitySetter: UIViewControllerRepresentable {
    let hidden: Bool

    func makeUIViewController(context: Context) -> Controller {
        Controller(hidden: hidden)
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {
        uiViewController.hidden = hidden
        uiViewController.applyVisibility()
    }

    final class Controller: UIViewController {
        var hidden: Bool

        init(hidden: Bool) {
            self.hidden = hidden
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.isUserInteractionEnabled = false
            view.backgroundColor = .clear
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            applyVisibility()
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            if hidden {
                setTabBarHidden(false)
            }
        }

        func applyVisibility() {
            setTabBarHidden(hidden)
        }

        private func setTabBarHidden(_ isHidden: Bool) {
            var controller: UIViewController? = self
            while let current = controller {
                if let tabBarController = current.tabBarController {
                    tabBarController.tabBar.isHidden = isHidden
                    return
                }
                controller = current.parent
            }
        }
    }
}
