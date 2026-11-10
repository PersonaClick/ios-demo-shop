import PersonaClick
import UIKit

/// Search results: the kit's `PersonalizationSearchResultsScreen` for the phrase submitted on Home.
///
/// The widget searches, pages, filters and tracks `search` on its own; the host only routes. Its
/// title carries a back arrow that returns to Home (the shop's stack has no bar). A tapped product
/// opens its page, the card button adds it to the cart, the sort button opens the shop's sort
/// sheet.
final class ShopSearchViewController: UIViewController {

    private let screen = PersonalizationSearchResultsScreen()

    init(query: String) {
        super.init(nibName: nil, bundle: nil)
        screen.shopId = ShopConfig.shopId
        screen.query = query
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = PersonalizationColor.backgroundGeneric

        screen.productActionText = Shop.actionText
        ShopSort.attach(to: screen, host: self)
        screen.onBack = { [weak self] in self?.navigationController?.popViewController(animated: true) }
        screen.onProductTap = { [weak self] product in self?.openShopProduct(product.id) }
        screen.onProductAction = { product in Shop.addToCart(productId: product.id, price: product.price) }
        screen.shopPinScreen(to: view)
    }
}
