//
//  MovieViewModel.swift
//  Task-app
//
//  Created by Fazil P on 28/04/2026.
//

import Foundation
import Combine

@MainActor
final class MovieViewModel: ObservableObject {
    @Published var movies: [Movie] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var searchText = ""
    @Published var selectedYear: String?
    @Published var fromDate: Date?
    @Published var toDate: Date?
    @Published var selectedCategory: MovieCategory = .trending
    @Published var hasReachedEnd = false
    @Published var newMoviesBanner: String?

    private let service: MovieServiceProtocol
    private let realtime: MovieRealtimeService
    private var currentPage = 1
    private var totalPages = 1
    private var loadTask: Task<Void, Never>?
    private var realtimeSubscription: AnyCancellable?
    private var bannerDismissTask: Task<Void, Never>?

    init(
        service: MovieServiceProtocol = MovieService(),
        realtime: MovieRealtimeService? = nil
    ) {
        self.service = service
        self.realtime = realtime ?? MovieRealtimeService.shared
        subscribeToRealtime()
    }

    deinit {
        loadTask?.cancel()
        bannerDismissTask?.cancel()
        realtimeSubscription?.cancel()
    }

    // MARK: - Loading

    func loadMovies(reset: Bool = false) async {
        if reset {
            loadTask?.cancel()
            loadTask = nil
            currentPage = 1
            totalPages = 1
            movies.removeAll()
            hasReachedEnd = false
            error = nil
        } else {
            if isLoading { return }
            if hasReachedEnd { return }
            guard currentPage <= totalPages else {
                hasReachedEnd = true
                return
            }
        }

        let task = Task { [currentPage, searchText, selectedYear, fromDate, toDate, selectedCategory] in
            await self.performLoad(
                page: currentPage,
                query: searchText.isEmpty ? nil : searchText,
                year: selectedYear,
                fromDate: fromDate,
                toDate: toDate,
                category: selectedCategory
            )
        }
        loadTask = task
        await task.value
    }

    private func performLoad(
        page: Int,
        query: String?,
        year: String?,
        fromDate: Date?,
        toDate: Date?,
        category: MovieCategory
    ) async {
        isLoading = true
        error = nil

        defer { isLoading = false }

        if let cached = MovieCache.shared.get(
            page: page,
            query: query,
            year: year,
            fromDate: fromDate,
            toDate: toDate,
            category: category.rawValue
        ) {
            appendIfStillCurrent(
                page: page,
                cached,
                query: query,
                year: year,
                fromDate: fromDate,
                toDate: toDate,
                category: category
            )
            return
        }

        do {
            let response = try await service.fetchMovies(
                page: page,
                query: query,
                year: year,
                fromDate: fromDate,
                toDate: toDate,
                category: category
            )

            guard !Task.isCancelled else { return }

            // Drop the response if filters/category changed mid-flight.
            guard isCurrentRequest(query: query, year: year, fromDate: fromDate, toDate: toDate, category: category) else {
                return
            }

            totalPages = response.totalPages
            movies.append(contentsOf: response.results)
            currentPage = page + 1

            if currentPage > totalPages {
                hasReachedEnd = true
            }

            MovieCache.shared.set(
                page: page,
                query: query,
                year: year,
                fromDate: fromDate,
                toDate: toDate,
                category: category.rawValue,
                movies: response.results
            )

            realtime.registerKnownIDs(movies.map(\.id))
            reconfigureRealtime()
        } catch is CancellationError {
            return
        } catch {
            if !Task.isCancelled {
                self.error = error.localizedDescription
            }
        }
    }

    private func appendIfStillCurrent(
        page: Int,
        _ cached: [Movie],
        query: String?,
        year: String?,
        fromDate: Date?,
        toDate: Date?,
        category: MovieCategory
    ) {
        guard isCurrentRequest(query: query, year: year, fromDate: fromDate, toDate: toDate, category: category) else {
            return
        }
        movies.append(contentsOf: cached)
        currentPage = page + 1
        if cached.isEmpty {
            hasReachedEnd = true
        }
        realtime.registerKnownIDs(movies.map(\.id))
    }

    private func isCurrentRequest(
        query: String?,
        year: String?,
        fromDate: Date?,
        toDate: Date?,
        category: MovieCategory
    ) -> Bool {
        let currentQuery = searchText.isEmpty ? nil : searchText
        return currentQuery == query
            && selectedYear == year
            && self.fromDate == fromDate
            && self.toDate == toDate
            && selectedCategory == category
    }

    func loadMoreIfNeeded(currentItem: Movie) async {
        guard !hasReachedEnd, !isLoading else { return }
        // Trigger the next page when the user reaches the last 4 items so
        // pagination feels seamless instead of stutter-loading at the very end.
        let triggerIndex = max(movies.count - 5, 0)
        if let index = movies.firstIndex(where: { $0.id == currentItem.id }), index >= triggerIndex {
            await loadMovies()
        }
    }

    // MARK: - Filter actions

    func applyFilter() async {
        await loadMovies(reset: true)
    }

    func selectCategory(_ category: MovieCategory) async {
        guard selectedCategory != category else { return }
        selectedCategory = category
        await loadMovies(reset: true)
    }

    func updateFilters(title: String, year: String?, fromDate: Date?, toDate: Date?) async {
        searchText = title.trimmingCharacters(in: .whitespacesAndNewlines)
        selectedYear = year
        self.fromDate = fromDate
        self.toDate = toDate
        await loadMovies(reset: true)
    }

    // MARK: - Real-time

    private func subscribeToRealtime() {
        realtimeSubscription = realtime.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] payload in
                self?.handleNewMovies(payload)
            }
        realtime.start()
    }

    private func reconfigureRealtime() {
        realtime.configure(
            category: selectedCategory,
            query: searchText.isEmpty ? nil : searchText,
            year: selectedYear,
            fromDate: fromDate,
            toDate: toDate,
            knownIDs: movies.map(\.id)
        )
    }

    private func handleNewMovies(_ payload: NewMoviesPayload) {
        let currentQuery = searchText.isEmpty ? nil : searchText
        guard payload.category == selectedCategory,
              payload.query == currentQuery,
              payload.year == selectedYear else {
            return
        }

        let existing = Set(movies.map(\.id))
        let truly = payload.movies.filter { !existing.contains($0.id) }
        guard !truly.isEmpty else { return }

        movies.insert(contentsOf: truly, at: 0)
        newMoviesBanner = truly.count == 1
            ? "1 new movie just dropped"
            : "\(truly.count) new movies just dropped"

        bannerDismissTask?.cancel()
        bannerDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            await MainActor.run {
                self?.newMoviesBanner = nil
            }
        }
    }
}
