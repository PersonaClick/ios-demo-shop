import UIKit
import PersonaClick

/// The shop's instant search on Home, behind the search button of its header.
///
/// The field renders its whole panel (recent searches, suggestions, categories, products) under
/// the input at all times, so the bar shows only the input until it is focused: then the panel
/// opens and the screen puts the rest of its content aside (`onSearchingChanged`); "Cancel" closes
/// it. A submitted phrase opens the results, a product its page, a category with an id the
/// category — on the navigation stack of `host`.
final class ShopSearchBar: UIView {

    let field = PersonalizationInstantSearchField()

    /// The screen the bar sits on: its view loses the focus, its stack gets the next screen.
    weak var host: UIViewController?

    /// The panel opened (`true`) or closed: the screen hides or brings back the rest of its content.
    var onSearchingChanged: ((Bool) -> Void)?

    private(set) var isSearching = false

    /// Browsing: the bar ends under the input, the panel below it is cut off.
    private lazy var collapsed = bottomAnchor.constraint(equalTo: field.view.input.bottomAnchor)
    /// Searching: the bar takes the whole field.
    private lazy var expanded = bottomAnchor.constraint(equalTo: field.bottomAnchor)

    init() {
        super.init(frame: .zero)
        clipsToBounds = true
        field.translatesAutoresizingMaskIntoConstraints = false
        addSubview(field)
        NSLayoutConstraint.activate([
            field.topAnchor.constraint(equalTo: topAnchor),
            field.leadingAnchor.constraint(equalTo: leadingAnchor),
            field.trailingAnchor.constraint(equalTo: trailingAnchor),
            collapsed
        ])
        setupField()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func setupField() {
        field.shopId = ShopConfig.shopId
        field.placeholder = "Search"
        field.recentLabel = "Recent searches"
        field.clearText = "Clear"
        field.moreText = "more"
        field.categoriesLabel = "Categories"
        field.productsLabel = "Products"
        field.showImages = true
        field.onSubmit = { [weak self] query in
            self?.close()
            self?.host?.openShopSearch(query)
        }
        field.onCancel = { [weak self] in self?.close() }
        field.onProductTap = { [weak self] product in
            self?.endEditingOnHost()
            self?.host?.openShopProduct(product.id)
        }
        field.onCategoryTap = { [weak self] category in
            // Popular categories of the empty state may come without an id — nothing to open them by.
            guard let id = category.id, !id.isEmpty else { return }
            self?.endEditingOnHost()
            self?.host?.openShopCategory(id: id, name: category.name)
        }
        field.view.input.textField.addTarget(self, action: #selector(focused), for: .editingDidBegin)
    }

    @objc private func focused() {
        setSearching(true)
    }

    /// Puts the cursor into the input: the keyboard comes up and the panel opens.
    func focus() {
        field.view.input.textField.becomeFirstResponder()
    }

    /// Back to browsing: the field is emptied and drops its instant results.
    func close() {
        field.query = nil
        // Text set in code does not send `.editingChanged`; sent here, it takes the field back to
        // its empty state the same way its own clear button does.
        field.view.input.textField.sendActions(for: .editingChanged)
        endEditingOnHost()
        setSearching(false)
    }

    private func endEditingOnHost() {
        (host?.view ?? self).endEditing(true)
    }

    private func setSearching(_ searching: Bool) {
        guard searching != isSearching else { return }
        isSearching = searching
        field.cancelText = searching ? "Cancel" : nil
        // Deactivate first: both pin the bottom of the bar.
        NSLayoutConstraint.deactivate([searching ? collapsed : expanded])
        NSLayoutConstraint.activate([searching ? expanded : collapsed])
        onSearchingChanged?(searching)
    }
}
