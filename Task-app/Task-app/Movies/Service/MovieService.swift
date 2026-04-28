//
//  MovieService.swift
//  Task-app
//
//  Created by Fazil P on 28/04/2026.
//

import Foundation

enum MovieCategory: String, CaseIterable {
    case trending
    case nowPlaying
    case topRated
    case upcoming
    case popular

    var title: String {
        switch self {
        case .trending: return "Trending"
        case .nowPlaying: return "Now Playing"
        case .topRated: return "Top Rated"
        case .upcoming: return "Upcoming"
        case .popular: return "Popular"
        }
    }
}

protocol MovieServiceProtocol {
    func fetchMovies(
        page: Int,
        query: String?,
        year: String?,
        fromDate: Date?,
        toDate: Date?,
        category: MovieCategory
    ) async throws -> MovieResponse
}

class MovieService: MovieServiceProtocol {
    private let apiKey = "f11c73e69dee8030e83b60d1fa4e189e"

    private static let isoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    func fetchMovies(
        page: Int,
        query: String?,
        year: String?,
        fromDate: Date?,
        toDate: Date?,
        category: MovieCategory
    ) async throws -> MovieResponse {
        let normalizedQuery = query?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedYear = year?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasQuery = !(normalizedQuery?.isEmpty ?? true)
        let hasYear = !(normalizedYear?.isEmpty ?? true)
        let hasDateRange = fromDate != nil || toDate != nil
        let endpoint: String

        if hasDateRange || (hasYear && !hasQuery) {
            endpoint = "discover/movie"
        } else if hasQuery {
            endpoint = "search/movie"
        } else {
            switch category {
            case .trending:
                endpoint = "trending/movie/day"
            case .nowPlaying:
                endpoint = "movie/now_playing"
            case .topRated:
                endpoint = "movie/top_rated"
            case .upcoming:
                endpoint = "movie/upcoming"
            case .popular:
                endpoint = "movie/popular"
            }
        }

        var components = URLComponents(string: "https://api.themoviedb.org/3/\(endpoint)")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "page", value: String(page))
        ]

        if endpoint == "search/movie", let query = normalizedQuery, !query.isEmpty {
            queryItems.append(URLQueryItem(name: "query", value: query))
        }

        if let normalizedYear, !normalizedYear.isEmpty {
            queryItems.append(URLQueryItem(name: "primary_release_year", value: normalizedYear))
        }

        if endpoint == "discover/movie" {
            queryItems.append(URLQueryItem(name: "sort_by", value: "popularity.desc"))
            queryItems.append(URLQueryItem(name: "include_adult", value: "false"))
            if let fromDate {
                queryItems.append(
                    URLQueryItem(
                        name: "primary_release_date.gte",
                        value: Self.isoDateFormatter.string(from: fromDate)
                    )
                )
            }
            if let toDate {
                queryItems.append(
                    URLQueryItem(
                        name: "primary_release_date.lte",
                        value: Self.isoDateFormatter.string(from: toDate)
                    )
                )
            }
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw MovieServiceError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw MovieServiceError.invalidResponse
        }

        do {
            let response = try JSONDecoder().decode(MovieResponse.self, from: data)
            let filteredResults = Self.applyLocalFilters(
                response.results,
                query: normalizedQuery,
                year: normalizedYear,
                fromDate: fromDate,
                toDate: toDate
            )

            return MovieResponse(
                page: response.page,
                results: filteredResults,
                totalPages: response.totalPages,
                totalResults: filteredResults.count
            )
        } catch {
            throw MovieServiceError.decodingError(error)
        }
    }

    private static func applyLocalFilters(
        _ movies: [Movie],
        query: String?,
        year: String?,
        fromDate: Date?,
        toDate: Date?
    ) -> [Movie] {
        let normalizedQuery = query?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedYear = year?.trimmingCharacters(in: .whitespacesAndNewlines)

        return movies.filter { movie in
            if let normalizedQuery, !normalizedQuery.isEmpty {
                let title = movie.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let original = movie.originalTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if !title.contains(normalizedQuery) && !original.contains(normalizedQuery) {
                    return false
                }
            }

            if let normalizedYear, !normalizedYear.isEmpty {
                let movieYear = String(movie.releaseDate.prefix(4))
                if movieYear != normalizedYear {
                    return false
                }
            }

            if fromDate != nil || toDate != nil {
                guard let releaseDate = isoDateFormatter.date(from: movie.releaseDate) else {
                    return false
                }
                if let fromDate, releaseDate < fromDate {
                    return false
                }
                if let toDate, releaseDate > toDate {
                    return false
                }
            }

            return true
        }
    }
}

enum MovieServiceError: Error {
    case invalidURL
    case invalidResponse
    case decodingError(Error)
    case unknown(Error)
}
