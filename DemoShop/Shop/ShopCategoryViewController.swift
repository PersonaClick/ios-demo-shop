import PersonaClick
import UIKit

/// Category: the kit's `PersonalizationCategoryScreen` as the whole screen, under the status bar.
///
/// The widget loads the category page by page, filters, sorts, tracks `categoryView` once and shows
/// the empty state and the error with "Retry" on its own; the host only routes. Its title is the
/// category name with a back arrow that returns along the shop's stack (the stack has no bar). A
/// tapped product opens its page, the card button adds it to the cart, the sort button opens the
/// shop's sort sheet. The search lives on Home.
final class ShopCategoryViewController: UIViewController {

    private let screen: PersonalizationCategoryScreen

    init(categoryId: String, name: String) {
        let screen = PersonalizationCategoryScreen(categoryId: categoryId, shopId: ShopConfig.shopId)
        screen.titleText = name
        self.screen = screen
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = PersonalizationColor.backgroundGeneric

        screen.productActionText = Shop.actionText
        screen.onBack = { [weak self] in self?.navigationController?.popViewController(animated: true) }
        screen.onProductTap = { [weak self] product in self?.openShopProduct(product.id ?? "") }
        screen.onProductAction = { product in
            Shop.addToCart(productId: product.id ?? "", price: product.price)
        }
        ShopSort.attach(to: screen, host: self)
        screen.shopPinScreen(to: view)
    }
}
