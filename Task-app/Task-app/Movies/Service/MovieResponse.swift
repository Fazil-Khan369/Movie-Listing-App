//
//  MovieResponse.swift
//  Task-app
//
//  Created by Fazil P on 28/04/2026.
//

import Foundation

// MARK: - MovieResponse
struct MovieResponse: Codable {
    let page: Int
    let results: [Movie]
    let totalPages, totalResults: Int

    // Backward-compatible aliases for existing snake_case usage.
    var total_pages: Int { totalPages }
    var total_results: Int { totalResults }

    enum CodingKeys: String, CodingKey {
        case page, results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }

    init(page: Int, results: [Movie], totalPages: Int, totalResults: Int) {
        self.page = page
        self.results = results
        self.totalPages = totalPages
        self.totalResults = totalResults
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        page = try container.decodeIfPresent(Int.self, forKey: .page) ?? 1
        totalPages = try container.decodeIfPresent(Int.self, forKey: .totalPages) ?? 1
        totalResults = try container.decodeIfPresent(Int.self, forKey: .totalResults) ?? 0

        var parsedMovies: [Movie] = []
        var moviesContainer = try container.nestedUnkeyedContainer(forKey: .results)
        while !moviesContainer.isAtEnd {
            do {
                let movie = try moviesContainer.decode(Movie.self)
                parsedMovies.append(movie)
            } catch {
                _ = try? moviesContainer.decode(SkipInvalidDecodable.self)
            }
        }
        results = parsedMovies
    }
}

private struct SkipInvalidDecodable: Decodable {}

