import Catalog
import Presentation
import Testing

struct CatalogErrorCopyTests {
    @Test(arguments: [
        (CatalogError.offline, "You're offline. Check your connection and try again.", nil as String?),
        (.timeout, "The catalog is taking too long to respond.", nil),
        (.server(status: 503), "The catalog service isn't responding. Try again in a moment.", "Error 503"),
        (.client(status: 404), "Something went wrong loading products.", "Error 404"),
        (.unreadable, "Something went wrong loading products.", nil),
        (.notFound, "This product is no longer available", "Error 404"),
    ])
    func failureShowsItsCopyAndAStatusCaptionOnlyForHTTP(error: CatalogError, message: String, caption: String?) {
        #expect(error.message == message)
        #expect(error.caption == caption)
    }
}
