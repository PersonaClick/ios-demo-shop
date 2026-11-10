import Foundation

/// Everything that ties the app to a shop. This is a demo shop — replace the values with your own.
enum ShopConfig {

    /// Shop identifier from your PersonaClick dashboard.
    static let shopId = "42a4cd11ebab3b0454778d18d4f3d5"

    /// Analytics stream. Passing the platform is the common choice: it keeps iOS and Android
    /// statistics apart.
    static let stream = "ios"

    // Recommender blocks found on the storefront of this shop, demo.personaclick.com. They are set
    // up in the dashboard; replace them with your own.

    /// Home: "Popular products". The shop runs an A/B test on it: segment B gets products,
    /// segment A an empty block, which the kit's block hides.
    static let homePopularCode = "3ced4017b680fee0d8d153bad996ff55"

    /// Product page: "Similar products", driven by the product on screen.
    static let productSimilarCode = "aabc899d3db3d71c4032832e4291c16a"

    /// Product page: "Recently viewed".
    static let productRecentlyViewedCode = "09db715d69d1284832a0ddeb2cf62ceb"

    /// Stories block of the shop's home. The storefront has none, so it is empty and home shows no
    /// stories bar; put a block code here to get one.
    static let storiesCode = ""
}
