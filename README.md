# Movie-Listing-App

`Task-app` is a SwiftUI iOS app that browses movies using TMDB, supports multi-criteria filtering, paginated loading, lightweight real-time updates, and a two-layer cache.

## API Used
This app uses **The Movie Database (TMDB) API v3**:
- Base URL: `https://api.themoviedb.org/3`
- Endpoints used:
  - `trending/movie/day`
  - `movie/now_playing`
  - `movie/top_rated`
  - `movie/upcoming`
  - `movie/popular`
  - `search/movie`
  - `discover/movie` (for date-range filtering)
Image loading uses TMDB image CDN:
- `https://image.tmdb.org/t/p/w500`
- `https://image.tmdb.org/t/p/w780`

## Pagination and Filtering Approach
### Pagination
- Server-side pagination via TMDB `page` query parameter.
- View model tracks `currentPage`, `totalPages`, and `hasReachedEnd`.
- Infinite-scroll style loading triggers when user scrolls near the end (last ~4 items) for smoother UX.
- On each successful load:
  - append results
  - increment `currentPage`
  - mark end when page limit reached
### Filtering
Supported filters:
- Free-text title search (`search/movie`)
- Release year (`primary_release_year`)
- Date range (`discover/movie` with `primary_release_date.gte/lte`)
- Category tabs (`trending`, `nowPlaying`, `topRated`, `upcoming`, `popular`)
Behavior details:
- If a date range is applied, app uses `discover/movie`.
- Else if query text exists, app uses `search/movie`.
- Otherwise app calls selected category endpoint.
- Applying filters/category resets pagination and reloads from page 1.
- In-flight stale responses are dropped if user changes filters while request is running.

## Caching / Data Store Strategy
The app uses a **two-layer cache** in `MovieCache`:
- In-memory dictionary for fast reads during session.
- Disk persistence as JSON file in `cachesDirectory` (`movie-cache.json`) for reuse across launches.
Cache key includes all request-defining inputs:
- category
- query
- year
- fromDate
- toDate
- page
This avoids cross-contamination between different filter combinations and page slices.

## Real-Time Messaging Approach

There is no websocket backend. "Real-time" updates are implemented as **client-side polling**:
- `MovieRealtimeService` polls every 30 seconds (default).
- Poll requests use current category/query/year/date filters and fetch page 1.
- Newly seen movie IDs are detected using a `knownIDs` set.
- New items are published using:
  - `Combine` (`PassthroughSubject<NewMoviesPayload, Never>`)
  - `NotificationCenter` (`.newMoviesAvailable`)
- View model inserts new items at top and shows a temporary "new movies" banner.
