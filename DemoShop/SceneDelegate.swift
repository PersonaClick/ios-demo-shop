import UIKit

/// The shop's window: its own navigation stack — Home → category → product, search — and nothing
/// else. The theme follows the system.
@available(iOS 13.0, *)
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = ShopNavigationController(rootViewController: ShopHomeViewController())
        window.makeKeyAndVisible()
        self.window = window
    }
}
