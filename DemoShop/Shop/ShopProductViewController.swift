import UIKit
import PersonaClick

/// Product page: `getProductInfo` — a card on top with the photo, brand, name, price with the old
/// price and the discount; under it recommender blocks for this product — similar and recently
/// viewed, each titled by the server and hidden while it has no products; and a bar pinned to the
/// bottom with the price and "Add to cart". Opening the page sends `productView`.
///
/// The page has no navigation bar and no search: the card runs under the status bar, a round back
/// button floats over it, the swipe back works too. While the product loads the page shows the
/// kit's loader in the middle; a failed request — the kit's empty state with the error text and
/// "Retry".
final class ShopProductViewController: UIViewController {

    private enum State {
        case loading, failed, loaded(ProductInfo)
    }

    private let productId: String
    private var sdk: PersonalizationSDK?
    private var sdkHandle: Cancellable?
    private var product: ProductInfo?
    /// Number of the request in flight: a late answer to an older one is dropped.
    private var requestSeq = 0

    private let scroll = UIScrollView()
    /// The card on top: the photo and the product's texts, rounded at the bottom.
    private let hero = UIView()
    /// Fills the space above the card when the page is pulled down, so the card never shows its top.
    private let heroBackdrop = UIView()
    private let photo = UIImageView()
    /// The photo starts under the status bar: the page scrolls under it and sets the gap itself.
    private lazy var photoTop = photo.topAnchor.constraint(equalTo: hero.topAnchor)
    private let brandLabel = UILabel()
    private let nameLabel = UILabel()
    private let priceLabel = UILabel()
    private let oldPriceLabel = UILabel()
    private let discountBadge = PersonalizationBadge(size: .md, view: .danger)
    private let blocks: [PersonalizationRecommenderBlock]
    private let backButton = ShopRoundButton.back()
    private let loader = PersonalizationLoader()
    private let errorState = PersonalizationEmptyState(message: Shop.errorText)
    /// The bar pinned to the bottom: price on the left, "Add to cart" on the rest of the width.
    private let cartBar = UIView()
    private let barPriceLabel = UILabel()
    private let barOldPriceLabel = UILabel()
    private let cartButton = PersonalizationButton(text: Shop.actionText, size: .lg, view: .primary)
    /// The page above the bar: "Added to cart" shows at its bottom, so the toast never covers the
    /// bar. Touches go through it.
    private let toastArea = UIView()

    init(productId: String) {
        self.productId = productId
        blocks = [ShopConfig.productSimilarCode, ShopConfig.productRecentlyViewedCode].map {
            PersonalizationRecommenderBlock(code: $0, itemId: productId, shopId: ShopConfig.shopId)
        }
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit {
        sdkHandle?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = PersonalizationColor.backgroundGeneric
        setupLayout()
        setupActions()
        render(.loading)
        sdkHandle = Shop.withSDK { [weak self] sdk in
            guard let self else { return }
            self.sdk = sdk
            // One event per opened page: "Retry" repeats the request, not the view.
            sdk.tracking.productView(itemId: self.productId)
            self.load()
        }
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        photoTop.constant = view.safeAreaInsets.top + PersonalizationSpacing.md
        scroll.verticalScrollIndicatorInsets.top = view.safeAreaInsets.top
    }

    private func load() {
        guard let sdk else { return }
        requestSeq += 1
        let seq = requestSeq
        render(.loading)
        sdk.getProductInfo(id: productId) { [weak self] result in
            DispatchQueue.main.async {
                guard let self, seq == self.requestSeq else { return }
                switch result {
                case .success(let product) where !product.id.isEmpty:
                    self.render(.loaded(product))
                case .success, .failure:
                    self.render(.failed)
                }
            }
        }
    }

    private func render(_ state: State) {
        loader.isHidden = true
        errorState.isHidden = true
        scroll.isHidden = true
        cartBar.isHidden = true
        switch state {
        case .loading:
            loader.isHidden = false
        case .failed:
            errorState.isHidden = false
        case .loaded(let product):
            scroll.isHidden = false
            cartBar.isHidden = false
            fill(product)
        }
    }

    /// The page shows the same strings a card of this product would: one mapper for both. The photo
    /// is `shopPhotoUrl`: large, over https.
    private func fill(_ product: ProductInfo) {
        self.product = product
        let card = product.shopCard
        ShopImageLoader.shared.load(product.shopPhotoUrl, into: photo)
        brandLabel.isHidden = card.brand == nil
        brandLabel.attributedText = styled(card.brand, PersonalizationTypography.smDefault, PersonalizationColor.textSecondary)
        nameLabel.attributedText = styled(card.name, PersonalizationTypography.xlEmphasized, PersonalizationColor.textPrimary)
        priceLabel.attributedText = styled(card.price, PersonalizationTypography.xl2Emphasized, PersonalizationColor.textPrimary)
        oldPriceLabel.isHidden = card.oldPrice == nil
        oldPriceLabel.attributedText = styled(
            card.oldPrice, PersonalizationTypography.baseDefault, PersonalizationColor.textSecondary, strikethrough: true
        )
        discountBadge.isHidden = card.discount == nil
        discountBadge.text = card.discount

        barPriceLabel.attributedText = styled(card.price, PersonalizationTypography.lgEmphasized, PersonalizationColor.textPrimary)
        barOldPriceLabel.isHidden = card.oldPrice == nil
        barOldPriceLabel.attributedText = styled(
            card.oldPrice, PersonalizationTypography.smDefault, PersonalizationColor.textSecondary, strikethrough: true
        )
    }

    /// Kit text style with a colour: only an attributed string carries the line height.
    private func styled(
        _ text: String?,
        _ style: PersonalizationTextStyle,
        _ color: UIColor,
        strikethrough: Bool = false
    ) -> NSAttributedString? {
        guard let text else { return nil }
        var attributes = style.attributes
        attributes[.foregroundColor] = color
        if strikethrough { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
        return NSAttributedString(string: text, attributes: attributes)
    }

    @objc private func cartTapped() {
        guard let product else { return }
        Shop.addToCart(productId: product.id, price: product.price, toastArea: toastArea)
    }

    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }
}

// MARK: - Layout

private extension ShopProductViewController {

    func setupLayout() {
        setupCartBar()

        // The card runs under the status bar, so the scroll does not shift its content by the
        // safe area: the photo keeps the gap itself (`photoTop`).
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.alwaysBounceVertical = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)

        setupHero()

        let blocksColumn = UIStackView(arrangedSubviews: blocks)
        blocksColumn.axis = .vertical
        // A block with no products is hidden, and the stack skips it along with its gap.
        blocksColumn.spacing = PersonalizationSpacing.xl3
        let blocksRow = blocksColumn.shopInset()

        let column = UIStackView(arrangedSubviews: [hero, blocksRow])
        column.axis = .vertical
        column.spacing = PersonalizationSpacing.xl3
        column.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(column)
        heroBackdrop.backgroundColor = PersonalizationColor.backgroundCard
        heroBackdrop.translatesAutoresizingMaskIntoConstraints = false
        scroll.insertSubview(heroBackdrop, belowSubview: column)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            // The content ends 24 above the bar.
            scroll.bottomAnchor.constraint(equalTo: cartBar.topAnchor),
            column.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            column.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -PersonalizationSpacing.xl3),
            column.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            column.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            column.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
            heroBackdrop.leadingAnchor.constraint(equalTo: hero.leadingAnchor),
            heroBackdrop.trailingAnchor.constraint(equalTo: hero.trailingAnchor),
            heroBackdrop.bottomAnchor.constraint(equalTo: hero.topAnchor, constant: PersonalizationRadius.modal),
            heroBackdrop.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
        ])

        loader.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loader)
        loader.startAnimating()
        errorState.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(errorState)
        NSLayoutConstraint.activate([
            loader.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loader.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            // The empty state centres its text and "Retry" in itself.
            errorState.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            errorState.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            errorState.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            errorState.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor)
        ])

        // The card's colour: invisible over the card, a plain bar over the blocks scrolled under it.
        shopCoverStatusBar(with: PersonalizationColor.backgroundCard)

        // Over everything, in every state: the way back while the product loads or fails too.
        backButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backButton)
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            backButton.leadingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: PersonalizationSpacing.paddingX
            )
        ])

        toastArea.isUserInteractionEnabled = false
        toastArea.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toastArea)
        NSLayoutConstraint.activate([
            toastArea.topAnchor.constraint(equalTo: view.topAnchor),
            toastArea.bottomAnchor.constraint(equalTo: cartBar.topAnchor),
            toastArea.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toastArea.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    /// The photo — a square two margins narrower than the screen, fitted — then brand, name and the
    /// price row with the page's inner margin.
    func setupHero() {
        hero.backgroundColor = PersonalizationColor.backgroundCard
        hero.layer.cornerRadius = PersonalizationRadius.modal
        hero.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]

        photo.contentMode = .scaleAspectFit
        photo.clipsToBounds = true
        photo.translatesAutoresizingMaskIntoConstraints = false
        hero.addSubview(photo)

        brandLabel.numberOfLines = 0
        nameLabel.numberOfLines = 0
        for view in [priceLabel, oldPriceLabel, discountBadge] {
            view.setContentHuggingPriority(.required, for: .horizontal)
        }
        let priceRow = UIStackView(arrangedSubviews: [priceLabel, oldPriceLabel, discountBadge, UIView()])
        priceRow.axis = .horizontal
        priceRow.alignment = .center
        priceRow.spacing = PersonalizationSpacing.md

        let texts = UIStackView(arrangedSubviews: [brandLabel, nameLabel, priceRow])
        texts.axis = .vertical
        texts.setCustomSpacing(PersonalizationSpacing.sm, after: brandLabel)  // 4
        texts.setCustomSpacing(PersonalizationSpacing.lg, after: nameLabel)   // 12
        texts.translatesAutoresizingMaskIntoConstraints = false
        hero.addSubview(texts)

        let inset = PersonalizationSpacing.xl2  // 20
        NSLayoutConstraint.activate([
            photoTop,
            photo.centerXAnchor.constraint(equalTo: hero.centerXAnchor),
            photo.widthAnchor.constraint(equalTo: hero.widthAnchor, constant: -2 * PersonalizationSpacing.xl4),
            photo.heightAnchor.constraint(equalTo: photo.widthAnchor),
            texts.topAnchor.constraint(equalTo: photo.bottomAnchor, constant: PersonalizationSpacing.md),
            texts.leadingAnchor.constraint(equalTo: hero.leadingAnchor, constant: inset),
            texts.trailingAnchor.constraint(equalTo: hero.trailingAnchor, constant: -inset),
            texts.bottomAnchor.constraint(equalTo: hero.bottomAnchor, constant: -inset)
        ])
    }

    /// Card surface with a hairline on top; its content stays above the home indicator, while the
    /// surface runs to the bottom edge.
    func setupCartBar() {
        cartBar.backgroundColor = PersonalizationColor.backgroundCard
        cartBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cartBar)

        let line = UIView()
        line.backgroundColor = PersonalizationColor.lineGenericSubtle
        line.translatesAutoresizingMaskIntoConstraints = false
        cartBar.addSubview(line)

        for label in [barPriceLabel, barOldPriceLabel] {
            label.setContentHuggingPriority(.required, for: .horizontal)
            label.setContentCompressionResistancePriority(.required, for: .horizontal)
        }
        let prices = UIStackView(arrangedSubviews: [barPriceLabel, barOldPriceLabel])
        prices.axis = .vertical
        prices.setContentHuggingPriority(.required, for: .horizontal)
        let row = UIStackView(arrangedSubviews: [prices, cartButton])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = PersonalizationSpacing.xl
        row.translatesAutoresizingMaskIntoConstraints = false
        cartBar.addSubview(row)

        NSLayoutConstraint.activate([
            cartBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cartBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cartBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            line.topAnchor.constraint(equalTo: cartBar.topAnchor),
            line.leadingAnchor.constraint(equalTo: cartBar.leadingAnchor),
            line.trailingAnchor.constraint(equalTo: cartBar.trailingAnchor),
            line.heightAnchor.constraint(equalToConstant: 1),
            row.topAnchor.constraint(equalTo: cartBar.topAnchor, constant: PersonalizationSpacing.lg),
            row.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -PersonalizationSpacing.lg),
            row.leadingAnchor.constraint(equalTo: cartBar.safeAreaLayoutGuide.leadingAnchor, constant: PersonalizationSpacing.paddingX),
            row.trailingAnchor.constraint(equalTo: cartBar.safeAreaLayoutGuide.trailingAnchor, constant: -PersonalizationSpacing.paddingX)
        ])
    }

    func setupActions() {
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        errorState.actionText = Shop.retryText
        errorState.onAction = { [weak self] in self?.load() }
        cartButton.addTarget(self, action: #selector(cartTapped), for: .touchUpInside)

        // The blocks load on their own as soon as they are on screen, in parallel with the product.
        for block in blocks {
            block.actionText = Shop.actionText
            block.onProductTap = { [weak self] product in self?.openShopProduct(product.id) }
            block.onProductAction = { [weak self] product in
                Shop.addToCart(productId: product.id, toastArea: self?.toastArea)
            }
        }
    }
}
