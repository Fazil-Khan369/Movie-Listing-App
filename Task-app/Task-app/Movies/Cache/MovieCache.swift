//
//  MovieCache.swift
//  Task-app
//
//  Created by Fazil P on 28/04/2026.
//



//  Two-layer cache: a fast in-memory dictionary backed by a JSON file on disk
//  so that repeated launches with the same filters can be served without a
//  network call. The cache is keyed by every parameter that influences the
//  TMDB response (category, query, year, date range, page), so different
//  filter combinations don't trample each other.
//

import Foundation

final class MovieCache {
    static let shared = MovieCache()

    private var memory: [String: [Movie]] = [:]
    private let queue = DispatchQueue(label: "MovieCache.queue", attributes: .concurrent)

    private static let isoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private var diskURL: URL? {
        guard let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        return dir.appendingPathComponent("movie-cache.json")
    }

    private init() {
        loadFromDisk()
    }

    func get(
        page: Int,
        query: String?,
        year: String?,
        fromDate: Date?,
        toDate: Date?,
        category: String
    ) -> [Movie]? {
        let key = cacheKey(page: page, query: query, year: year, fromDate: fromDate, toDate: toDate, category: category)
        return queue.sync { memory[key] }
    }

    func set(
        page: Int,
        query: String?,
        year: String?,
        fromDate: Date?,
        toDate: Date?,
        category: String,
        movies: [Movie]
    ) {
        let key = cacheKey(page: page, query: query, year: year, fromDate: fromDate, toDate: toDate, category: category)
        queue.async(flags: .barrier) { [weak self] in
            self?.memory[key] = movies
            self?.saveToDisk()
        }
    }

    func clear() {
        queue.async(flags: .barrier) { [weak self] in
            self?.memory.removeAll()
            if let url = self?.diskURL {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    private func cacheKey(
        page: Int,
        query: String?,
        year: String?,
        fromDate: Date?,
        toDate: Date?,
        category: String
    ) -> String {
        let queryValue = (query?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "none"
        let yearValue = (year?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "none"
        let fromValue = fromDate.map { Self.isoDateFormatter.string(from: $0) } ?? "none"
        let toValue = toDate.map { Self.isoDateFormatter.string(from: $0) } ?? "none"
        return "\(category)|\(queryValue)|\(yearValue)|\(fromValue)|\(toValue)|\(page)"
    }

    private func loadFromDisk() {
        guard let url = diskURL,
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return
        }
        if let decoded = try? JSONDecoder().decode([String: [Movie]].self, from: data) {
            memory = decoded
        }
    }

    private func saveToDisk() {
        guard let url = diskURL else { return }
        guard let data = try? JSONEncoder().encode(memory) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
