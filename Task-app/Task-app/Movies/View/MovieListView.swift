//
//  MovieListView.swift
//  Task-app
//
//  Created by Fazil P on 28/04/2026.
//


import SwiftUI

struct MovieListView: View {
    @StateObject private var vm = MovieViewModel()
    @State private var selectedBottomTab: AppBottomTab = .discover
    @State private var isShowingFilters = false

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [Color.black, Color(red: 0.14, green: 0.03, blue: 0.03)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        HeaderSection {
                            isShowingFilters = true
                        }

                        SearchSection(searchText: $vm.searchText) {
                            Task {
                                await vm.applyFilter()
                            }
                        }

                        ActiveFiltersSection(
                            title: vm.searchText,
                            selectedYear: vm.selectedYear
                        )

                        CategoryTabsSection(
                            selectedCategory: vm.selectedCategory,
                            onSelect: { category in
                                Task {
                                    await vm.selectCategory(category)
                                }
                            }
                        )

                        if let banner = vm.newMoviesBanner {
                            NewMoviesBanner(message: banner)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        MovieGridSection(
                            movies: vm.movies,
                            isLoading: vm.isLoading,
                            error: vm.error,
                            hasReachedEnd: vm.hasReachedEnd,
                            onLoadMore: { movie in
                                Task {
                                    await vm.loadMoreIfNeeded(currentItem: movie)
                                }
                            }
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 110)
                }

                Spacer(minLength: 0)
            }

            BottomNavBar(selectedTab: $selectedBottomTab)
        }
        .task {
            await vm.loadMovies()
        }
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $isShowingFilters) {
            FiltersView(
                initialTitle: vm.searchText,
                initialSelectedYear: vm.selectedYear,
                initialFromDate: vm.fromDate,
                initialToDate: vm.toDate
            ) { title, year, fromDate, toDate in
                Task {
                    await vm.updateFilters(
                        title: title,
                        year: year,
                        fromDate: fromDate,
                        toDate: toDate
                    )
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: vm.newMoviesBanner)
    }
}

private struct ActiveFiltersSection: View {
    let title: String
    let selectedYear: String?

    private var normalizedTitle: String? {
        let value = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    var body: some View {
        if normalizedTitle != nil || selectedYear != nil {
            HStack(spacing: 10) {
                if let normalizedTitle {
                    filterChip(label: "Title: \(normalizedTitle)")
                }
                if let selectedYear {
                    filterChip(label: "Year: \(selectedYear)")
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func filterChip(label: String) -> some View {
        Text(label)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white.opacity(0.92))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.red.opacity(0.26))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.red.opacity(0.42), lineWidth: 1)
                    )
            )
    }
}

private struct NewMoviesBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 15, weight: .semibold))
            Text(message)
                .font(.system(size: 14, weight: .semibold))
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.red.opacity(0.85))
        )
    }
}

private struct HeaderSection: View {
    let onFilterTap: () -> Void

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "popcorn.fill")
                    .font(.system(size: 17, weight: .bold))
                Text("CINEVIEW")
                    .font(.system(size: 30, weight: .black, design: .serif))
            }
            .foregroundStyle(Color.red)

            Spacer()

            Button(action: onFilterTap) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white.opacity(0.88))
            }
        }
        .padding(.top, 4)
    }
}

private struct SearchSection: View {
    @Binding var searchText: String
    let onSubmit: () -> Void

    var body: some View {
        HStack {
            HStack {
                TextField("Search movies, shows, genres...", text: $searchText)
                    .foregroundStyle(.white.opacity(0.9))
                    .tint(.red)
                    .submitLabel(.search)
                    .onSubmit(onSubmit)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.white.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
    }
}

private struct CategoryTabsSection: View {
    let selectedCategory: MovieCategory
    let onSelect: (MovieCategory) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(MovieCategory.allCases, id: \.rawValue) { category in
                    let isSelected = selectedCategory == category
                    Button(action: { onSelect(category) }) {
                        Text(category.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(isSelected ? .white : .white.opacity(0.8))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 11)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(isSelected ? Color.red : Color.white.opacity(0.08))
                            )
                    }
                }
            }
        }
    }
}

private struct MovieGridSection: View {
    let movies: [Movie]
    let isLoading: Bool
    let error: String?
    let hasReachedEnd: Bool
    let onLoadMore: (Movie) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        VStack(spacing: 16) {
            if let error {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red.opacity(0.9))
                    .padding(.top, 4)
            }

            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(movies) { movie in
                    MovieCard(movie: movie)
                        .onAppear {
                            onLoadMore(movie)
                        }
                }
            }

            if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(.white.opacity(0.85))
                    Text("Loading more...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.vertical, 8)
            } else if movies.isEmpty {
                Text("No movies match your filters yet.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 30)
            } else if hasReachedEnd {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal")
                    Text("You've reached the end")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
                .padding(.top, 6)
                .padding(.bottom, 4)
            }
        }
    }
}

private struct MovieCard: View {
    let movie: Movie

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AsyncImage(url: posterURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                LinearGradient(
                    colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(height: 250)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            LinearGradient(
                colors: [.clear, .black.opacity(0.85)],
                startPoint: .center,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Spacer()
                Text(displayTitle)
                    .font(.system(size: 17, weight: .heavy, design: .serif))
                    .lineLimit(2)
                    .foregroundStyle(.white)
                Text(releaseYearText)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(12)

            Image(systemName: "bookmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
                .padding(8)
                .background(.black.opacity(0.28), in: Circle())
                .padding(10)
        }
        .frame(height: 250)
    }

    private var posterURL: URL? {
        if let posterPath = normalizedImagePath(movie.posterPath) {
            return URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")
        }

        if let backdropPath = normalizedImagePath(movie.backdropPath) {
            return URL(string: "https://image.tmdb.org/t/p/w780\(backdropPath)")
        }

        return nil
    }

    private var releaseYearText: String {
        let trimmedDate = movie.release_date.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedDate.isEmpty {
            return "Release date unavailable"
        }
        return String(trimmedDate.prefix(4))
    }

    private var displayTitle: String {
        let primary = movie.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !primary.isEmpty { return primary }
        let fallback = movie.originalTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return fallback.isEmpty ? "Untitled" : fallback
    }

    private func normalizedImagePath(_ rawPath: String?) -> String? {
        guard let rawPath else { return nil }
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.hasPrefix("/") ? trimmed : "/\(trimmed)"
    }
}

private enum AppBottomTab: String, CaseIterable {
    case home = "house"
    case discover = "safari"
    case watchlist = "bookmark"
    case profile = "person"

    var title: String {
        switch self {
        case .home: return "Home"
        case .discover: return "Discover"
        case .watchlist: return "Watchlist"
        case .profile: return "Profile"
        }
    }
}

private struct BottomNavBar: View {
    @Binding var selectedTab: AppBottomTab

    var body: some View {
        HStack {
            ForEach(AppBottomTab.allCases, id: \.rawValue) { tab in
                Spacer()
                let isSelected = selectedTab == tab
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.rawValue)
                            .font(.system(size: 20, weight: .medium))
                        Text(tab.title)
                            .font(.caption2)
                    }
                    .foregroundStyle(isSelected ? Color.red : .white.opacity(0.7))
                }
                Spacer()
            }
        }
        .padding(.vertical, 14)
        .background(Color.black.opacity(0.95))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }
}

