/// Answers captured from https://dummyjson.com on 2026-11-02, as served apart from indentation.
enum Payloads {
    /// `GET /products?limit=3&skip=151`: products 152–154. No brand on 152 and 153; one of each
    /// availability label; 153 has stock 0.
    static let page = #"""
    {
      "products": [
        {
          "id": 152,
          "title": "Tennis Racket",
          "description": "The Tennis Racket is an essential piece of equipment used in the sport of tennis. It features a frame with strings and a grip, allowing players to hit the tennis ball.",
          "category": "sports-accessories",
          "price": 49.99,
          "discountPercentage": 19.61,
          "rating": 4.03,
          "stock": 6,
          "tags": [
            "sports equipment",
            "tennis"
          ],
          "sku": "SPO-BRD-TEN-152",
          "weight": 7,
          "dimensions": {
            "width": 17.7,
            "height": 16.38,
            "depth": 18.74
          },
          "warrantyInformation": "5 year warranty",
          "shippingInformation": "Ships overnight",
          "availabilityStatus": "Low Stock",
          "reviews": [
            {
              "rating": 3,
              "comment": "Poor quality!",
              "date": "2025-04-30T09:41:02.054Z",
              "reviewerName": "Mason Parker",
              "reviewerEmail": "mason.parker@x.dummyjson.com"
            },
            {
              "rating": 5,
              "comment": "Highly impressed!",
              "date": "2025-04-30T09:41:02.054Z",
              "reviewerName": "Gabriel Bailey",
              "reviewerEmail": "gabriel.bailey@x.dummyjson.com"
            },
            {
              "rating": 5,
              "comment": "Highly recommended!",
              "date": "2025-04-30T09:41:02.054Z",
              "reviewerName": "Lincoln Kelly",
              "reviewerEmail": "lincoln.kelly@x.dummyjson.com"
            }
          ],
          "returnPolicy": "7 days return policy",
          "minimumOrderQuantity": 5,
          "meta": {
            "createdAt": "2025-03-10T20:50:42.333Z",
            "updatedAt": "2025-09-19T17:06:35.012Z",
            "barcode": "5611498376196",
            "qrCode": "https://cdn.dummyjson.com/public/qr-code.png"
          },
          "images": [
            "https://cdn.dummyjson.com/product-images/sports-accessories/tennis-racket/1.webp"
          ],
          "thumbnail": "https://cdn.dummyjson.com/product-images/sports-accessories/tennis-racket/thumbnail.webp"
        },
        {
          "id": 153,
          "title": "Volleyball",
          "description": "The Volleyball is a standard ball used in the sport of volleyball. It is designed for passing, setting, and spiking over the net during volleyball matches.",
          "category": "sports-accessories",
          "price": 11.99,
          "discountPercentage": 12.25,
          "rating": 3.84,
          "stock": 0,
          "tags": [
            "sports equipment",
            "volleyball"
          ],
          "sku": "SPO-BRD-VOL-153",
          "weight": 3,
          "dimensions": {
            "width": 17.01,
            "height": 20.05,
            "depth": 9.94
          },
          "warrantyInformation": "1 week warranty",
          "shippingInformation": "Ships in 1 week",
          "availabilityStatus": "Out of Stock",
          "reviews": [
            {
              "rating": 4,
              "comment": "Great product!",
              "date": "2025-04-30T09:41:02.054Z",
              "reviewerName": "Carter Rivera",
              "reviewerEmail": "carter.rivera@x.dummyjson.com"
            },
            {
              "rating": 1,
              "comment": "Would not recommend!",
              "date": "2025-04-30T09:41:02.054Z",
              "reviewerName": "Eli Ward",
              "reviewerEmail": "eli.ward@x.dummyjson.com"
            },
            {
              "rating": 4,
              "comment": "Highly recommended!",
              "date": "2025-04-30T09:41:02.054Z",
              "reviewerName": "Emma Wilson",
              "reviewerEmail": "emma.wilson@x.dummyjson.com"
            }
          ],
          "returnPolicy": "90 days return policy",
          "minimumOrderQuantity": 44,
          "meta": {
            "createdAt": "2026-05-24T21:49:26.491Z",
            "updatedAt": "2026-06-09T07:25:45.495Z",
            "barcode": "6348576170594",
            "qrCode": "https://cdn.dummyjson.com/public/qr-code.png"
          },
          "images": [
            "https://cdn.dummyjson.com/product-images/sports-accessories/volleyball/1.webp"
          ],
          "thumbnail": "https://cdn.dummyjson.com/product-images/sports-accessories/volleyball/thumbnail.webp"
        },
        {
          "id": 154,
          "title": "Black Sun Glasses",
          "description": "The Black Sun Glasses are a classic and stylish choice, featuring a sleek black frame and tinted lenses. They provide both UV protection and a fashionable look.",
          "category": "sunglasses",
          "price": 29.99,
          "discountPercentage": 4.94,
          "rating": 4.41,
          "stock": 60,
          "tags": [
            "eyewear",
            "sunglasses"
          ],
          "brand": "Fashion Shades",
          "sku": "SUN-FAS-BLA-154",
          "weight": 1,
          "dimensions": {
            "width": 18.51,
            "height": 15.69,
            "depth": 10.11
          },
          "warrantyInformation": "No warranty",
          "shippingInformation": "Ships in 1-2 business days",
          "availabilityStatus": "In Stock",
          "reviews": [
            {
              "rating": 3,
              "comment": "Would not recommend!",
              "date": "2025-04-30T09:41:02.054Z",
              "reviewerName": "Jonathan Pierce",
              "reviewerEmail": "jonathan.pierce@x.dummyjson.com"
            },
            {
              "rating": 2,
              "comment": "Disappointing product!",
              "date": "2025-04-30T09:41:02.054Z",
              "reviewerName": "Owen Fisher",
              "reviewerEmail": "owen.fisher@x.dummyjson.com"
            },
            {
              "rating": 4,
              "comment": "Very happy with my purchase!",
              "date": "2025-04-30T09:41:02.054Z",
              "reviewerName": "Samantha Martinez",
              "reviewerEmail": "samantha.martinez@x.dummyjson.com"
            }
          ],
          "returnPolicy": "7 days return policy",
          "minimumOrderQuantity": 17,
          "meta": {
            "createdAt": "2025-09-07T18:03:27.535Z",
            "updatedAt": "2026-01-09T09:29:38.063Z",
            "barcode": "1045032983803",
            "qrCode": "https://cdn.dummyjson.com/public/qr-code.png"
          },
          "images": [
            "https://cdn.dummyjson.com/product-images/sunglasses/black-sun-glasses/1.webp",
            "https://cdn.dummyjson.com/product-images/sunglasses/black-sun-glasses/2.webp",
            "https://cdn.dummyjson.com/product-images/sunglasses/black-sun-glasses/3.webp"
          ],
          "thumbnail": "https://cdn.dummyjson.com/product-images/sunglasses/black-sun-glasses/thumbnail.webp"
        }
      ],
      "total": 194,
      "skip": 151,
      "limit": 3
    }
    """#

    /// `GET /products/1`: price 9.99, discount 10.48.
    static let product = #"""
    {
      "id": 1,
      "title": "Essence Mascara Lash Princess",
      "description": "The Essence Mascara Lash Princess is a popular mascara known for its volumizing and lengthening effects. Achieve dramatic lashes with this long-lasting and cruelty-free formula.",
      "category": "beauty",
      "price": 9.99,
      "discountPercentage": 10.48,
      "rating": 2.56,
      "stock": 99,
      "tags": [
        "beauty",
        "mascara"
      ],
      "brand": "Essence",
      "sku": "BEA-ESS-ESS-001",
      "weight": 4,
      "dimensions": {
        "width": 15.14,
        "height": 13.08,
        "depth": 22.99
      },
      "warrantyInformation": "1 week warranty",
      "shippingInformation": "Ships in 3-5 business days",
      "availabilityStatus": "In Stock",
      "reviews": [
        {
          "rating": 3,
          "comment": "Would not recommend!",
          "date": "2025-04-30T09:41:02.053Z",
          "reviewerName": "Eleanor Collins",
          "reviewerEmail": "eleanor.collins@x.dummyjson.com"
        },
        {
          "rating": 4,
          "comment": "Very satisfied!",
          "date": "2025-04-30T09:41:02.053Z",
          "reviewerName": "Lucas Gordon",
          "reviewerEmail": "lucas.gordon@x.dummyjson.com"
        },
        {
          "rating": 5,
          "comment": "Highly impressed!",
          "date": "2025-04-30T09:41:02.053Z",
          "reviewerName": "Eleanor Collins",
          "reviewerEmail": "eleanor.collins@x.dummyjson.com"
        }
      ],
      "returnPolicy": "No return policy",
      "minimumOrderQuantity": 48,
      "meta": {
        "createdAt": "2025-10-09T14:47:01.588Z",
        "updatedAt": "2026-05-23T11:27:41.868Z",
        "barcode": "5784719087687",
        "qrCode": "https://cdn.dummyjson.com/public/qr-code.png"
      },
      "images": [
        "https://cdn.dummyjson.com/product-images/beauty/essence-mascara-lash-princess/1.webp"
      ],
      "thumbnail": "https://cdn.dummyjson.com/product-images/beauty/essence-mascara-lash-princess/thumbnail.webp"
    }
    """#

    /// `GET /products/categories`: 24 categories.
    static let categories = #"""
    [
      {
        "slug": "beauty",
        "name": "Beauty",
        "url": "https://dummyjson.com/products/category/beauty"
      },
      {
        "slug": "fragrances",
        "name": "Fragrances",
        "url": "https://dummyjson.com/products/category/fragrances"
      },
      {
        "slug": "furniture",
        "name": "Furniture",
        "url": "https://dummyjson.com/products/category/furniture"
      },
      {
        "slug": "groceries",
        "name": "Groceries",
        "url": "https://dummyjson.com/products/category/groceries"
      },
      {
        "slug": "home-decoration",
        "name": "Home Decoration",
        "url": "https://dummyjson.com/products/category/home-decoration"
      },
      {
        "slug": "kitchen-accessories",
        "name": "Kitchen Accessories",
        "url": "https://dummyjson.com/products/category/kitchen-accessories"
      },
      {
        "slug": "laptops",
        "name": "Laptops",
        "url": "https://dummyjson.com/products/category/laptops"
      },
      {
        "slug": "mens-shirts",
        "name": "Mens Shirts",
        "url": "https://dummyjson.com/products/category/mens-shirts"
      },
      {
        "slug": "mens-shoes",
        "name": "Mens Shoes",
        "url": "https://dummyjson.com/products/category/mens-shoes"
      },
      {
        "slug": "mens-watches",
        "name": "Mens Watches",
        "url": "https://dummyjson.com/products/category/mens-watches"
      },
      {
        "slug": "mobile-accessories",
        "name": "Mobile Accessories",
        "url": "https://dummyjson.com/products/category/mobile-accessories"
      },
      {
        "slug": "motorcycle",
        "name": "Motorcycle",
        "url": "https://dummyjson.com/products/category/motorcycle"
      },
      {
        "slug": "skin-care",
        "name": "Skin Care",
        "url": "https://dummyjson.com/products/category/skin-care"
      },
      {
        "slug": "smartphones",
        "name": "Smartphones",
        "url": "https://dummyjson.com/products/category/smartphones"
      },
      {
        "slug": "sports-accessories",
        "name": "Sports Accessories",
        "url": "https://dummyjson.com/products/category/sports-accessories"
      },
      {
        "slug": "sunglasses",
        "name": "Sunglasses",
        "url": "https://dummyjson.com/products/category/sunglasses"
      },
      {
        "slug": "tablets",
        "name": "Tablets",
        "url": "https://dummyjson.com/products/category/tablets"
      },
      {
        "slug": "tops",
        "name": "Tops",
        "url": "https://dummyjson.com/products/category/tops"
      },
      {
        "slug": "vehicle",
        "name": "Vehicle",
        "url": "https://dummyjson.com/products/category/vehicle"
      },
      {
        "slug": "womens-bags",
        "name": "Womens Bags",
        "url": "https://dummyjson.com/products/category/womens-bags"
      },
      {
        "slug": "womens-dresses",
        "name": "Womens Dresses",
        "url": "https://dummyjson.com/products/category/womens-dresses"
      },
      {
        "slug": "womens-jewellery",
        "name": "Womens Jewellery",
        "url": "https://dummyjson.com/products/category/womens-jewellery"
      },
      {
        "slug": "womens-shoes",
        "name": "Womens Shoes",
        "url": "https://dummyjson.com/products/category/womens-shoes"
      },
      {
        "slug": "womens-watches",
        "name": "Womens Watches",
        "url": "https://dummyjson.com/products/category/womens-watches"
      }
    ]
    """#

    /// `GET /products/search?q=zzzz`: no matches.
    static let emptySearch = #"{"products":[],"total":0,"skip":0,"limit":0}"#

    /// `GET /products/999`: the body of its 404.
    static let notFound = #"{"message":"Product with id '999' not found"}"#
}
