import PersonaClick
import UIKit

/// Shop home: the header ("Shop" and a search button), the stories bar, the recommender carousel
/// and the top-level categories, one column under the status bar.
///
/// The search is the shop's `ShopSearchBar` behind the header's button: the button puts the bar in
/// place of the header, focused, with its panel open, and the rest of Home steps aside; "Cancel" or
/// a submitted phrase brings the header and Home back.
///
/// The stories bar is there only when `ShopConfig.storiesCode` is set; a product tapped in a story
/// opens its page by the id the stories callbacks carry.
final class ShopHomeViewController: UIViewController {

    private let scroll = UIScrollView()
    private let header = UILabel()
    private let searchButton = ShopRoundButton.search()
    private let searchBar = ShopSearchBar()
    /// The row of the title and the button, and the row of the search bar that takes its place
    /// while searching.
    private var headerRow = UIView()
    private var searchRow = UIView()
    private let stories: PersonalizationStories? = ShopConfig.storiesCode.isEmpty
        ? nil
        : PersonalizationStories(code: ShopConfig.storiesCode, shopId: ShopConfig.shopId)
    private let recommender = PersonalizationRecommenderBlock(code: ShopConfig.homePopularCode, shopId: ShopConfig.shopId)
    private let categories = ShopCategoriesSection()
    /// Rows hidden while the search panel is open.
    private var browseRows: [UIView] = []
    /// The last story tap opened a product: its link stays with the shop, not the SDK.
    private var storyProductOpened = false
    private var sdkHandle: Cancellable?

    deinit {
        sdkHandle?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Shop"
        view.backgroundColor = PersonalizationColor.backgroundGeneric
        setupSearch()
        setupBlocks()
        setupLayout()
        sdkHandle = Shop.withSDK { [weak self] sdk in self?.categories.load(with: sdk) }
    }

    private func setupSearch() {
        searchBar.host = self
        searchBar.onSearchingChanged = { [weak self] searching in self?.showSearch(searching) }
        searchButton.addTarget(self, action: #selector(searchTapped), for: .touchUpInside)
    }

    @objc private func searchTapped() {
        // The bar has to be on screen to take the focus; the focus opens its panel.
        showSearch(true)
        searchBar.focus()
    }

    private func showSearch(_ searching: Bool) {
        headerRow.isHidden = searching
        searchRow.isHidden = !searching
        browseRows.forEach { $0.isHidden = searching }
        scroll.setContentOffset(CGPoint(x: 0, y: -scroll.adjustedContentInset.top), animated: false)
    }

    private func setupBlocks() {
        if let stories {
            // The covers start at the page margin; the column sets the gaps above and below the bar.
            stories.bar.contentInsets = UIEdgeInsets(
                top: 0, left: PersonalizationSpacing.paddingX, bottom: 0, right: PersonalizationSpacing.paddingX
            )
            stories.promoCopiedText = "Code copied"
            stories.hostViewController = self
            stories.communicationDelegate = self
        }

        recommender.actionText = Shop.actionText
        recommender.onProductTap = { [weak self] product in self?.openShopProduct(product.id) }
        recommender.onProductAction = { product in Shop.addToCart(productId: product.id) }

        categories.onSelect = { [weak self] item in self?.openShopCategory(id: item.id, name: item.name) }
    }
}

// MARK: - Layout

private extension ShopHomeViewController {

    func setupLayout() {
        scroll.alwaysBounceVertical = true
        scroll.keyboardDismissMode = .onDrag
        scroll.shopPin(to: view)

        var title = PersonalizationTypography.xl3Emphasized.attributes
        title[.foregroundColor] = PersonalizationColor.textPrimary
        header.attributedText = NSAttributedString(string: "Shop", attributes: title)
        header.accessibilityTraits = .header
        let headerStack = UIStackView(arrangedSubviews: [header, searchButton])
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.spacing = PersonalizationSpacing.lg
        headerRow = headerStack.shopInset()
        searchRow = searchBar.shopInset()
        searchRow.isHidden = true

        // The widgets hide themselves when they have nothing to show; Home hides their rows
        // instead, so leaving the search never brings back a block that hid itself.
        let storiesRow = stories?.shopInset(horizontal: 0)
        let recommenderRow = recommender.shopInset()
        let categoriesRow = categories.shopInset()
        browseRows = [storiesRow, recommenderRow, categoriesRow].compactMap { $0 }

        let column = UIStackView(arrangedSubviews: [headerRow, searchRow] + browseRows)
        column.axis = .vertical
        // A hidden row takes its gap along: the gap of the row before it stays.
        column.setCustomSpacing(PersonalizationSpacing.lg, after: headerRow)         // 12
        column.setCustomSpacing(PersonalizationSpacing.lg, after: searchRow)         // 12
        if let storiesRow {
            column.setCustomSpacing(PersonalizationSpacing.xl3, after: storiesRow)   // 24
        }
        column.setCustomSpacing(PersonalizationSpacing.xl3, after: recommenderRow)   // 24
        column.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(column)
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: PersonalizationSpacing.md),
            column.bottomAnchor.constraint(
                equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -PersonalizationSpacing.xl4
            ),
            column.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            column.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            column.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)
        ])
        shopCoverStatusBar(with: PersonalizationColor.backgroundGeneric)
    }
}

// MARK: - Stories

/// The stories callbacks of the SDK: a tapped product comes with its id — the product element, the
/// slide button of a product slide, a carousel card — and opens its page here. The viewer is closed
/// by then; the SDK asks next whether to open the product's link itself, and the shop declines.
/// Other links (a button to a web page) the SDK opens.
extension ShopHomeViewController: StoriesCommunicationProtocol {

    func receiveIosLink(text: String) {}

    func receiveSelectedProductData(products: StoriesElement) {
        openStoryProduct(products.productId)
    }

    func receiveSelectedCarouselProductData(products: StoriesProduct) {
        openStoryProduct(products.id)
    }

    /// A copied promo code: nothing to open.
    func receiveSelectedPromocodeProductData(promoCodeSlide: StoriesPromoCodeElement) {}

    func shouldOpenLinkBySdk(url: String) -> Bool {
        defer { storyProductOpened = false }
        return !storyProductOpened
    }

    private func openStoryProduct(_ id: String?) {
        storyProductOpened = !(id ?? "").isEmpty
        if let id, storyProductOpened { openShopProduct(id) }
    }
}
