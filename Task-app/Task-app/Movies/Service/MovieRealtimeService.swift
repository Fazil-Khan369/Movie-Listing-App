//
//  MovieRealtimeService.swift
//  Task-app
//
//  Created by Fazil P on 28/04/2026.
//

import Foundation
import Combine

extension Notification.Name {
    static let newMoviesAvailable = Notification.Name("MovieRealtimeService.newMoviesAvailable")
}

struct NewMoviesPayload {
    let category: MovieCategory
    let query: String?
    let year: String?
    let movies: [Movie]
}

@MainActor
final class MovieRealtimeService {
    static let shared = MovieRealtimeService()

    let publisher = PassthroughSubject<NewMoviesPayload, Never>()

    private let service: MovieServiceProtocol
    private let pollInterval: TimeInterval
    private var pollingTask: Task<Void, Never>?

    private var category: MovieCategory = .trending
    private var query: String?
    private var year: String?
    private var fromDate: Date?
    private var toDate: Date?
    private var knownIDs: Set<Int> = []

    init(service: MovieServiceProtocol = MovieService(), pollInterval: TimeInterval = 30) {
        self.service = service
        self.pollInterval = pollInterval
    }

    func configure(
        category: MovieCategory,
        query: String?,
        year: String?,
        fromDate: Date?,
        toDate: Date?,
        knownIDs: [Int]
    ) {
        self.category = category
        self.query = query
        self.year = year
        self.fromDate = fromDate
        self.toDate = toDate
        self.knownIDs = Set(knownIDs)
    }

    func registerKnownIDs(_ ids: [Int]) {
        knownIDs.formUnion(ids)
    }

    func start() {
        stop()
        pollingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(self.pollInterval * 1_000_000_000))
                if Task.isCancelled { return }
                await self.pollOnce()
            }
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func pollOnce() async {
        do {
            let response = try await service.fetchMovies(
                page: 1,
                query: query,
                year: year,
                fromDate: fromDate,
                toDate: toDate,
                category: category
            )

            let fresh = response.results.filter { !knownIDs.contains($0.id) }
            guard !fresh.isEmpty else { return }

            knownIDs.formUnion(fresh.map(\.id))

            let payload = NewMoviesPayload(
                category: category,
                query: query,
                year: year,
                movies: fresh
            )

            publisher.send(payload)
            NotificationCenter.default.post(
                name: .newMoviesAvailable,
                object: nil,
                userInfo: ["payload": payload]
            )
        } catch {
            // Keep polling even when one request fails.
        }
    }
}
