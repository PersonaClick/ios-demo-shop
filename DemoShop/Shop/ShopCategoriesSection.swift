import UIKit
import PersonaClick

/// "Categories" on Home: the top-level categories of the shop under the kit's title — the same
/// title the recommender block has — as kit rows with a chevron in one rounded group.
///
/// The list is the `categories` of `getProductsList` without a parent.
/// While it loads — the kit's loader; when it fails — the kit's empty state with the shop's error
/// text and "Retry"; no categories — the section hides.
final class ShopCategoriesSection: UIStackView {

    struct Item {
        let id: String
        let name: String
    }

    var onSelect: ((Item) -> Void)?

    private var sdk: PersonalizationSDK?
    private var items: [Item] = []
    private var requestSeq = 0
    /// The rounded card of the rows; the rows and the lines between them go into `rows`.
    private let group = UIView()
    private let rows = UIStackView()
    private let loaderRow = UIView()
    private let errorState = PersonalizationEmptyState(message: Shop.errorText)

    init() {
        super.init(frame: .zero)
        axis = .vertical
        spacing = PersonalizationSpacing.lg  // 12

        rows.axis = .vertical
        group.backgroundColor = PersonalizationColor.backgroundCard
        group.layer.cornerRadius = PersonalizationRadius.card
        group.clipsToBounds = true
        rows.shopPin(to: group)

        let loader = PersonalizationLoader()
        loader.translatesAutoresizingMaskIntoConstraints = false
        loaderRow.addSubview(loader)
        NSLayoutConstraint.activate([
            loader.centerXAnchor.constraint(equalTo: loaderRow.centerXAnchor),
            loader.topAnchor.constraint(equalTo: loaderRow.topAnchor, constant: PersonalizationSpacing.md),
            loader.bottomAnchor.constraint(equalTo: loaderRow.bottomAnchor, constant: -PersonalizationSpacing.md)
        ])
        loader.startAnimating()

        errorState.actionText = Shop.retryText
        errorState.onAction = { [weak self] in self?.reload() }

        for view in [PersonalizationTitle(text: "Categories"), loaderRow, errorState, group] {
            addArrangedSubview(view)
        }
        errorState.isHidden = true
        group.isHidden = true
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func load(with sdk: PersonalizationSDK) {
        self.sdk = sdk
        reload()
    }

    private func reload() {
        guard let sdk else { return }
        requestSeq += 1
        let seq = requestSeq
        loaderRow.isHidden = false
        errorState.isHidden = true
        // One product is enough: only the categories of the response are read.
        sdk.getProductsList(limit: 1) { [weak self] result in
            let items = try? result.get().categories
                .filter { !$0.id.isEmpty && ($0.parentId ?? "").isEmpty }
                .map { Item(id: $0.id, name: $0.name) }
            DispatchQueue.main.async {
                guard let self, seq == self.requestSeq else { return }
                self.render(items)
            }
        }
    }

    /// `nil` — the request failed.
    private func render(_ items: [Item]?) {
        loaderRow.isHidden = true
        errorState.isHidden = items != nil
        isHidden = items?.isEmpty == true
        self.items = items ?? []
        group.isHidden = self.items.isEmpty
        rows.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, item) in self.items.enumerated() {
            if index > 0 { rows.addArrangedSubview(Self.divider()) }
            let row = ShopCategoryRow(title: item.name, index: index)
            row.addTarget(self, action: #selector(rowTapped(_:)), for: .touchUpInside)
            rows.addArrangedSubview(row)
        }
    }

    @objc private func rowTapped(_ row: ShopCategoryRow) {
        guard items.indices.contains(row.index) else { return }
        onSelect?(items[row.index])
    }

    /// The line between two rows, across the whole group.
    private static func divider() -> UIView {
        let line = UIView()
        line.backgroundColor = PersonalizationColor.lineGenericSubtle
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return line
    }
}

/// A kit category row as a row of the group: the page margin on both sides, at least the height of
/// a list row, and the tap and the pressed state on the whole width, margins included.
private final class ShopCategoryRow: UIControl {

    let index: Int

    override var isHighlighted: Bool {
        didSet { backgroundColor = isHighlighted ? PersonalizationColor.backgroundGeneric : nil }
    }

    init(title: String, index: Int) {
        self.index = index
        super.init(frame: .zero)
        let row = PersonalizationSuggestionRow(kind: .category)
        row.title = title
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        // A two-line name makes the row taller than 52; otherwise the row is 52 with the name centred.
        let height = heightAnchor.constraint(equalToConstant: Self.minHeight)
        height.priority = .defaultLow
        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: Self.minHeight),
            height,
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
            row.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: PersonalizationSpacing.md),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: PersonalizationSpacing.paddingX),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -PersonalizationSpacing.paddingX)
        ])
        isAccessibilityElement = true
        accessibilityLabel = title
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private static let minHeight: CGFloat = 52
}
