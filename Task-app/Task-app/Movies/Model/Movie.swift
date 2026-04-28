//
//  Movie.swift
//  Task-app
//
//  Created by Fazil P on 28/04/2026.
//

import Foundation

struct Movie: Codable, Identifiable {
    let adult: Bool
    let backdropPath: String?
    let genreIDS: [Int]
    let id: Int
    let originalLanguage: String
    let originalTitle: String
    let overview: String
    let popularity: Double
    let posterPath: String?
    let releaseDate: String
    let title: String
    let video: Bool
    let voteAverage: Double
    let voteCount: Int

    // Backward-compatible aliases for existing snake_case usage.
    var release_date: String { releaseDate }
    var poster_path: String? { posterPath }

    enum CodingKeys: String, CodingKey {
        case adult
        case backdropPath = "backdrop_path"
        case genreIDS = "genre_ids"
        case id
        case originalLanguage = "original_language"
        case originalTitle = "original_title"
        case popularity
        case overview
        case posterPath = "poster_path"
        case releaseDate = "release_date"
        case title, video
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        adult = try container.decodeIfPresent(Bool.self, forKey: .adult) ?? false
        backdropPath = try container.decodeIfPresent(String.self, forKey: .backdropPath)
        genreIDS = Self.decodeGenreIDs(from: container)
        id = try container.decode(Int.self, forKey: .id)
        originalLanguage = try container.decodeIfPresent(String.self, forKey: .originalLanguage) ?? ""
        originalTitle = try container.decodeIfPresent(String.self, forKey: .originalTitle) ?? ""
        overview = try container.decodeIfPresent(String.self, forKey: .overview) ?? ""
        popularity = Self.decodeDouble(forKey: .popularity, from: container)
        posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
        releaseDate = try container.decodeIfPresent(String.self, forKey: .releaseDate) ?? ""
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Untitled"
        video = try container.decodeIfPresent(Bool.self, forKey: .video) ?? false
        voteAverage = Self.decodeDouble(forKey: .voteAverage, from: container)
        voteCount = Self.decodeInt(forKey: .voteCount, from: container)
    }

    private static func decodeDouble(
        forKey key: CodingKeys,
        from container: KeyedDecodingContainer<CodingKeys>
    ) -> Double {
        if let value = try? container.decodeIfPresent(Double.self, forKey: key) {
            return value ?? 0
        }
        if let intValue = try? container.decodeIfPresent(Int.self, forKey: key) {
            return Double(intValue ?? 0)
        }
        if let stringValue = try? container.decodeIfPresent(String.self, forKey: key),
           let parsed = Double(stringValue ?? "") {
            return parsed
        }
        return 0
    }

    private static func decodeInt(
        forKey key: CodingKeys,
        from container: KeyedDecodingContainer<CodingKeys>
    ) -> Int {
        if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
            return value ?? 0
        }
        if let doubleValue = try? container.decodeIfPresent(Double.self, forKey: key) {
            return Int(doubleValue ?? 0)
        }
        if let stringValue = try? container.decodeIfPresent(String.self, forKey: key),
           let parsed = Int(stringValue ?? "") {
            return parsed
        }
        return 0
    }

    private static func decodeGenreIDs(from container: KeyedDecodingContainer<CodingKeys>) -> [Int] {
        if let ids = try? container.decodeIfPresent([Int].self, forKey: .genreIDS) {
            return ids ?? []
        }

        if let idStrings = try? container.decodeIfPresent([String].self, forKey: .genreIDS) {
            return (idStrings ?? []).compactMap(Int.init)
        }

        return []
    }
}
