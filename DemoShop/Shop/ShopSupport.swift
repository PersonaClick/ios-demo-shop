import PersonaClick
import UIKit

/// The shop — a small store built from the SDK's UI kit and its public methods, the way a host app
/// would wire them: Home (instant search, stories, a recommender block, categories), a category, a
/// product page and search results, on one navigation stack without a bar.
///
/// There is no cart screen: "Add to cart" sends the `cart` event and shows the kit's toast.
/// Navigation is the host's — the widgets only hand products and categories over.
enum Shop {

    static let actionText = "Add to cart"
    static let errorText = "Something went wrong. Check your connection and try again."
    static let retryText = "Retry"

    /// The SDK instance of the shop, on the main thread, as soon as it is registered — the same
    /// resolution the kit's widgets do by `shopId`. A screen cancels the result when it goes away;
    /// a one-off call may drop it.
    @discardableResult
    static func withSDK(_ body: @escaping (PersonalizationSDK) -> Void) -> Cancellable {
        PersonaClick.awaitInstance(for: ShopConfig.shopId) { sdk in
            if Thread.isMainThread {
                body(sdk)
            } else {
                DispatchQueue.main.async { body(sdk) }
            }
        }
    }

    /// "Add to cart": the `cart` event and the kit's toast. A recommender block has already
    /// remembered itself as the source of the event (`dynamic` with its code) before it hands the
    /// product over.
    ///
    /// - Parameter toastArea: where the toast shows, at the bottom of its safe area; `nil` — the
    ///   window. The product page passes the space above its pinned bar.
    static func addToCart(productId: String, price: Double? = nil, toastArea: UIView? = nil) {
        guard !productId.isEmpty else { return }
        withSDK { sdk in
            sdk.tracking.addToCart(item: TrackingItem(id: productId, price: price))
        }
        PersonalizationToast.show("Added to cart", in: toastArea)
    }
}

// MARK: - Navigation

/// The shop's navigation stack. Every screen of the shop draws its own top — Home its title with a
/// search button, a category and search results the kit's header with a back arrow, a product a
/// round back button over the photo — so the bar stays hidden on all of them.
///
/// A hidden bar turns the swipes back off: UIKit's own delegate of the swipes refuses them without
/// a bar. The stack becomes their delegate and lets them begin on every screen above the root — the
/// swipe from the edge and, from iOS 26, the one across the content. How a swipe shares the touch
/// with a carousel stays with the swipe itself.
final class ShopNavigationController: UINavigationController, UIGestureRecognizerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        setNavigationBarHidden(true, animated: false)
        interactivePopGestureRecognizer?.delegate = self
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            interactiveContentPopGestureRecognizer?.delegate = self
        }
        #endif
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Nothing to go back to on Home; a swipe in the middle of a push would break the stack.
        viewControllers.count > 1 && transitionCoordinator == nil
    }
}

/// Every screen of the shop goes onto the shop's navigation stack.
extension UIViewController {

    func openShopProduct(_ id: String) {
        guard !id.isEmpty else { return }
        navigationController?.pushViewController(ShopProductViewController(productId: id), animated: true)
    }

    func openShopCategory(id: String, name: String) {
        guard !id.isEmpty else { return }
        navigationController?.pushViewController(ShopCategoryViewController(categoryId: id, name: name), animated: true)
    }

    func openShopSearch(_ query: String) {
        navigationController?.pushViewController(ShopSearchViewController(query: query), animated: true)
    }
}

// MARK: - Layout

extension UIViewController {

    /// A strip of `color` over the status bar: content scrolled up goes under it rather than under
    /// the clock — the shop has no navigation bar to cover it. Added on top of what is already there.
    func shopCoverStatusBar(with color: UIColor) {
        let strip = UIView()
        strip.backgroundColor = color
        strip.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(strip)
        NSLayoutConstraint.activate([
            strip.topAnchor.constraint(equalTo: view.topAnchor),
            strip.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            strip.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            strip.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
}

extension UIView {

    /// The view inside a plain container with side margins — for rows of a full-width stack.
    func shopInset(horizontal: CGFloat = PersonalizationSpacing.paddingX) -> UIView {
        let container = UIView()
        translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(self)
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: container.topAnchor),
            bottomAnchor.constraint(equalTo: container.bottomAnchor),
            leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: horizontal),
            trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -horizontal)
        ])
        return container
    }

    /// A full-screen kit widget (a category, search results) under the status bar: its own header
    /// starts 8 below the safe area, the rest of the screen is the widget's.
    func shopPinScreen(to parent: UIView) {
        translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(self)
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: parent.safeAreaLayoutGuide.topAnchor, constant: PersonalizationSpacing.md),
            bottomAnchor.constraint(equalTo: parent.bottomAnchor),
            leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            trailingAnchor.constraint(equalTo: parent.trailingAnchor)
        ])
    }

    /// Pins the view to the edges of `parent`.
    func shopPin(to parent: UIView) {
        translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(self)
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: parent.topAnchor),
            bottomAnchor.constraint(equalTo: parent.bottomAnchor),
            leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            trailingAnchor.constraint(equalTo: parent.trailingAnchor)
        ])
    }
}

/// A round 44 button with a kit icon: back over the product's card, search in the header of Home.
final class ShopRoundButton: UIControl {

    private let icon = UIImageView()

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.6 : 1 }
    }

    init(icon image: UIImage?, background: UIColor, label: String) {
        super.init(frame: .zero)
        backgroundColor = background
        layer.cornerRadius = min(PersonalizationRadius.rounded, Self.side / 2)

        icon.image = image
        icon.tintColor = PersonalizationColor.textPrimary
        icon.contentMode = .scaleAspectFit
        icon.isUserInteractionEnabled = false
        icon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(icon)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.side),
            heightAnchor.constraint(equalToConstant: Self.side),
            icon.centerXAnchor.constraint(equalTo: centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: Self.iconSide),
            icon.heightAnchor.constraint(equalToConstant: Self.iconSide)
        ])

        isAccessibilityElement = true
        accessibilityLabel = label
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Back over the product's card: on the page background, the kit's chevron pointing back (the
    /// kit has it pointing right only, so it is mirrored).
    static func back() -> ShopRoundButton {
        ShopRoundButton(
            icon: PersonalizationIcons.angleLargeRight?.withHorizontallyFlippedOrientation(),
            background: PersonalizationColor.backgroundGeneric,
            label: "Back"
        )
    }

    /// Search in the header of Home: on the card surface, the kit's magnifier.
    static func search() -> ShopRoundButton {
        ShopRoundButton(icon: PersonalizationIcons.magnifier, background: PersonalizationColor.backgroundCard, label: "Search")
    }

    private static let side: CGFloat = 44
    private static let iconSide: CGFloat = 24
}

// MARK: - Images

/// Loads the product page's photo. The kit's widgets load their images themselves; the product
/// page draws its photo with a plain image view, so the shop keeps this small loader for it.
final class ShopImageLoader {

    static let shared = ShopImageLoader()

    private let cache = NSCache<NSString, UIImage>()
    /// The URL each image view is waiting for, so a late response cannot overwrite a newer request.
    private var pending: [ObjectIdentifier: URL] = [:]

    func load(_ urlString: String?, into imageView: UIImageView) {
        imageView.image = nil
        guard let urlString, let url = URL(string: urlString) else {
            pending[ObjectIdentifier(imageView)] = nil
            return
        }
        if let cached = cache.object(forKey: urlString as NSString) {
            pending[ObjectIdentifier(imageView)] = nil
            imageView.image = cached
            return
        }
        pending[ObjectIdentifier(imageView)] = url
        URLSession.shared.dataTask(with: url) { [weak self, weak imageView] data, _, _ in
            guard let self, let data, let image = UIImage(data: data) else { return }
            self.cache.setObject(image, forKey: urlString as NSString)
            DispatchQueue.main.async {
                guard let imageView, self.pending[ObjectIdentifier(imageView)] == url else { return }
                self.pending[ObjectIdentifier(imageView)] = nil
                imageView.image = image
            }
        }.resume()
    }
}
