import Foundation
import PersonaClick

/// SDK product → kit card, for the screen that fetches its product itself (the product page).
///
/// The kit maps products inside its data-bound widgets, but that mapper is internal, so the demo
/// keeps a small one with the same rules:
/// - price — `price_formatted`, otherwise the number with the currency;
/// - old price — `oldprice_formatted`, only when the old price is above the price;
/// - discount badge — only next to the old price and only for a positive `discount`, otherwise
///   `discount_percent`; its text is `discount_formatted` (it describes `discount`), otherwise
///   "<number>%", with exactly one "-" in front;
/// - image — `picture` (the resized copy), otherwise the original; no rating in the API.
enum ShopProductMapper {

    struct Fields {
        var id: String
        var name: String
        var price: Double
        var priceFormatted: String?
        var currency: String?
        var oldPrice: Double?
        var oldPriceFormatted: String?
        var discount: Int?
        var discountFormatted: String?
        var discountPercent: Int?
        var picture: String?
        var imageUrl: String?
        var brand: String?
        var url: String?
        var deeplink: String?
    }

    static func card(_ fields: Fields, actionText: String? = Shop.actionText) -> PersonalizationProduct {
        let oldPriceText = text(fields.oldPriceFormatted)
        let hasOldPrice = (fields.oldPrice ?? 0) > fields.price && oldPriceText != nil
        var discountText: String?
        if hasOldPrice {
            if let discount = fields.discount, discount > 0 {
                discountText = badge(fields.discountFormatted, discount)
            } else if let percent = fields.discountPercent, percent > 0 {
                discountText = badge(nil, percent)
            }
        }
        return PersonalizationProduct(
            id: fields.id,
            name: fields.name,
            price: text(fields.priceFormatted) ?? "\(fields.price) \(fields.currency ?? "")",
            imageUrl: text(fields.picture) ?? text(fields.imageUrl),
            brand: text(fields.brand),
            oldPrice: hasOldPrice ? oldPriceText : nil,
            discount: discountText,
            actionText: actionText,
            url: text(fields.url),
            deeplink: text(fields.deeplink)
        )
    }

    /// "6%", "-6%" and "--6%" all become "-6%"; nothing formatted — the number with "%".
    private static func badge(_ formatted: String?, _ number: Int) -> String {
        let body = (formatted ?? "").trimmingCharacters(in: .whitespaces).drop { $0 == "-" || $0 == "\u{2212}" }
        return "-" + (body.isEmpty ? "\(number)%" : String(body))
    }

    /// Missing strings come as `nil` or as "" depending on the model — both mean "none".
    private static func text(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}

extension ProductInfo {
    /// The product of `getProductInfo` as kit card data — the product page renders its fields.
    var shopCard: PersonalizationProduct {
        ShopProductMapper.card(ShopProductMapper.Fields(
            id: id, name: name, price: price, priceFormatted: priceFormatted, currency: currency,
            oldPrice: oldPrice, oldPriceFormatted: oldPriceFormatted,
            discount: discount, discountFormatted: discountFormatted, discountPercent: discountPercent,
            picture: resizedImageUrl, imageUrl: imageUrl, brand: brand, url: url, deeplink: deeplinkIos
        ))
    }

    /// The photo of the product page: the original, big enough for the page, otherwise the largest
    /// resized copy — an https address first. App Transport Security loads no plain-http pictures,
    /// and this catalog serves its originals over http, its resized copies over https.
    var shopPhotoUrl: String? {
        let resized = resizedImages
            .sorted { (Int($0.key) ?? 0) > (Int($1.key) ?? 0) }
            .map { $0.value }
        let candidates = ([imageUrl] + resized + [resizedImageUrl]).filter { !$0.isEmpty }
        return candidates.first { $0.hasPrefix("https:") } ?? candidates.first
    }
}
