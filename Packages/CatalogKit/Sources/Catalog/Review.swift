import Foundation

/// A customer review. The payload's reviewer e-mail is deliberately never decoded.
public struct Review: Hashable, Sendable {
    public var rating: Int
    public var comment: String
    public var date: Date
    public var reviewerName: String

    public init(rating: Int, comment: String, date: Date, reviewerName: String) {
        self.rating = rating
        self.comment = comment
        self.date = date
        self.reviewerName = reviewerName
    }
}

extension Review: Decodable {
    private enum CodingKeys: String, CodingKey {
        case rating, comment, date, reviewerName
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rating = try container.decode(Int.self, forKey: .rating)
        comment = try container.decode(String.self, forKey: .comment)
        reviewerName = try container.decode(String.self, forKey: .reviewerName)
        let rawDate = try container.decode(String.self, forKey: .date)
        do {
            date = try Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(rawDate)
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: .date,
                in: container,
                debugDescription: "Expected an ISO 8601 date with fractional seconds, got \(rawDate)"
            )
        }
    }
}
