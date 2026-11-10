import UIKit
import PersonaClick

/// Sorting of the shop's results and categories. The kit's design has no sort picker, so the shop
/// shows its own bottom sheet from the screen's sort button; the choice goes to the screen's
/// `sortBy` / `sortDir`, and the screen loads the first page again.
enum ShopSort: CaseIterable {
    case relevance, priceAscending, priceDescending, discount

    var title: String {
        switch self {
        case .relevance: return "Relevance"
        case .priceAscending: return "Price: low to high"
        case .priceDescending: return "Price: high to low"
        case .discount: return "Discount"
        }
    }

    /// `sort_by` / `sort_dir` of the request; relevance is no sorting at all.
    var params: (sortBy: String?, sortDir: String?) {
        switch self {
        case .relevance: return (nil, nil)
        case .priceAscending: return ("price", "asc")
        case .priceDescending: return ("price", "desc")
        case .discount: return ("discount", "desc")
        }
    }

    /// The sort button of `screen` opens the sheet over `host`.
    static func attach<Item>(to screen: PersonalizationResultsScreen<Item>, host: UIViewController) {
        screen.onSortTap = { [weak screen, weak host] in
            guard let screen, let host else { return }
            let current = allCases.first { $0.params == (screen.sortBy, screen.sortDir) } ?? .relevance
            let sheet = ShopSortSheet(current: current) { [weak screen] option in
                screen?.sortBy = option.params.sortBy
                screen?.sortDir = option.params.sortDir
            }
            host.present(sheet, animated: true)
        }
    }
}

/// The sort sheet: "Sort by" and the orders as rows, the current one with a check mark; a tap picks
/// an order and closes the sheet. Kit text styles and colours on the modal surface with the modal
/// radius; the sheet is as tall as its rows.
private final class ShopSortSheet: UIViewController {

    private let current: ShopSort
    private let onPick: (ShopSort) -> Void
    private let column = UIStackView()

    init(current: ShopSort, onPick: @escaping (ShopSort) -> Void) {
        self.current = current
        self.onPick = onPick
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        guard #available(iOS 15.0, *), let sheet = sheetPresentationController else { return }
        if #available(iOS 16.0, *) {
            sheet.detents = [.custom { [weak self] _ in self?.contentHeight() }]
        } else {
            sheet.detents = [.medium()]
        }
        sheet.prefersGrabberVisible = true
        sheet.preferredCornerRadius = PersonalizationRadius.modal
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = PersonalizationColor.backgroundModal

        let title = UILabel()
        var attributes = PersonalizationTypography.lgEmphasized.attributes
        attributes[.foregroundColor] = PersonalizationColor.textPrimary
        title.attributedText = NSAttributedString(string: "Sort by", attributes: attributes)
        title.accessibilityTraits = .header
        let titleRow = title.shopInset(horizontal: PersonalizationSpacing.paddingModal)

        column.axis = .vertical
        column.addArrangedSubview(titleRow)
        column.setCustomSpacing(PersonalizationSpacing.md, after: titleRow)
        for option in ShopSort.allCases {
            let row = ShopSortRow(option: option, selected: option == current)
            row.addTarget(self, action: #selector(rowTapped(_:)), for: .touchUpInside)
            column.addArrangedSubview(row)
        }
        column.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(column)
        NSLayoutConstraint.activate([
            // Clear of the grabber.
            column.topAnchor.constraint(equalTo: view.topAnchor, constant: PersonalizationSpacing.xl3),
            column.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            column.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            column.bottomAnchor.constraint(
                lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -PersonalizationSpacing.md
            )
        ])
    }

    /// The height of the sheet above the bottom safe area: the sheet adds the safe area itself.
    private func contentHeight() -> CGFloat {
        loadViewIfNeeded()
        let width = presentingViewController?.view.bounds.width ?? view.bounds.width
        let size = column.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        return PersonalizationSpacing.xl3 + size.height + PersonalizationSpacing.md
    }

    @objc private func rowTapped(_ row: ShopSortRow) {
        onPick(row.option)
        dismiss(animated: true)
    }
}

/// An order in the sheet: its name and, for the current one, a check mark in the brand colour.
private final class ShopSortRow: UIControl {

    let option: ShopSort

    override var isHighlighted: Bool {
        didSet { backgroundColor = isHighlighted ? PersonalizationColor.backgroundGeneric : nil }
    }

    init(option: ShopSort, selected: Bool) {
        self.option = option
        super.init(frame: .zero)

        let label = UILabel()
        var attributes = PersonalizationTypography.baseDefault.attributes
        attributes[.foregroundColor] = PersonalizationColor.textPrimary
        label.attributedText = NSAttributedString(string: option.title, attributes: attributes)

        let check = UIImageView(image: Self.checkMark)
        check.tintColor = PersonalizationColor.brandPrimary
        check.contentMode = .scaleAspectFit
        check.isHidden = !selected
        check.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [label, check])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = PersonalizationSpacing.lg
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: Self.minHeight),
            row.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: PersonalizationSpacing.md),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: PersonalizationSpacing.paddingModal),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -PersonalizationSpacing.paddingModal)
        ])
        let height = heightAnchor.constraint(equalToConstant: Self.minHeight)
        height.priority = .defaultLow
        height.isActive = true

        isAccessibilityElement = true
        accessibilityLabel = option.title
        accessibilityTraits = selected ? [.button, .selected] : .button
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private static let minHeight: CGFloat = 52

    /// The kit has no plain check mark among its icons: the shop draws its own, 24 × 24, as a
    /// template tinted by the row.
    private static let checkMark: UIImage = {
        let side: CGFloat = 24
        let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { _ in
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 9, y: 16.17))
            path.addLine(to: CGPoint(x: 4.83, y: 12))
            path.addLine(to: CGPoint(x: 3.41, y: 13.41))
            path.addLine(to: CGPoint(x: 9, y: 19))
            path.addLine(to: CGPoint(x: 21, y: 7))
            path.addLine(to: CGPoint(x: 19.59, y: 5.59))
            path.close()
            UIColor.black.setFill()
            path.fill()
        }
        return image.withRenderingMode(.alwaysTemplate)
    }()
}
