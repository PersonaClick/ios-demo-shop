import PersonaClick
import UIKit

/// Starts the SDK and shows the shop.
///
/// One SDK instance for the whole app, created before the first screen: the kit's widgets find it
/// by `ShopConfig.shopId` on their own. The SDK keeps its registered instances weakly, so the app
/// holds this one for as long as it runs.
///
/// Popups of the dashboard need nothing here: the SDK shows them over the top screen by default.
/// The app has no push set-up, so the SDK neither asks for the notification permission nor sends a
/// push token (`autoSendPushToken: false`).
@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {

    /// The window on iOS 12; from iOS 13 the scene owns it (`SceneDelegate`).
    var window: UIWindow?

    private(set) var sdk: PersonalizationSDK?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        sdk = PersonaClick.initialize(PersonaClickConfig(
            shopId: ShopConfig.shopId,
            stream: ShopConfig.stream,
            enableLogs: Self.enableLogs,
            autoSendPushToken: false
        ))

        if #available(iOS 13.0, *) {
            return true
        }
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = ShopNavigationController(rootViewController: ShopHomeViewController())
        window.makeKeyAndVisible()
        self.window = window
        return true
    }

    @available(iOS 13.0, *)
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    /// The SDK's network log, in debug builds only.
    private static var enableLogs: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
