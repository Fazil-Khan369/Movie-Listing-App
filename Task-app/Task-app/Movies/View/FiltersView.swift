//
//  FiltersView.swift
//  Task-app
//
//  Created by Fazil P on 28/04/2026.
//

import SwiftUI

struct FiltersView: View {
    let initialTitle: String
    let initialSelectedYear: String?
    let initialFromDate: Date?
    let initialToDate: Date?
    let onApply: (_ title: String, _ selectedYear: String?, _ fromDate: Date?, _ toDate: Date?) -> Void

    @State private var title = ""
    @State private var selectedYear: String?
    @State private var sliderYear = Double(FiltersConstants.maxYear)
    @State private var fromDate = Date()
    @State private var toDate = Date()
    @State private var hasFromDate = false
    @State private var hasToDate = false

    @Environment(\.dismiss) private var dismiss

    init(
        initialTitle: String,
        initialSelectedYear: String?,
        initialFromDate: Date? = nil,
        initialToDate: Date? = nil,
        onApply: @escaping (_ title: String, _ selectedYear: String?, _ fromDate: Date?, _ toDate: Date?) -> Void
    ) {
        self.initialTitle = initialTitle
        self.initialSelectedYear = initialSelectedYear
        self.initialFromDate = initialFromDate
        self.initialToDate = initialToDate
        self.onApply = onApply
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.08, green: 0.03, blue: 0.04)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 30) {
                    header
                    titleSection
                    releaseYearSection
                    dateRangeSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 120)
            }
        }
        .safeAreaInset(edge: .bottom) {
            applyButton
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: configureInitialValues)
    }

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 34, height: 34)
            }

            Spacer()

            Text("FILTERS")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)

            Spacer()

            Button("Reset") {
                resetAll()
            }
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(.white.opacity(0.68))
        }
        .padding(.top, 4)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Title")

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.45))

                TextField("Search by movie title...", text: $title)
                    .foregroundStyle(.white.opacity(0.9))
                    .tint(.red)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
    }

    private var releaseYearSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                sectionTitle("Release Year")
                Spacer()
                Text(selectedYearBadge)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.red.opacity(0.95))
            }

            HStack(spacing: 10) {
                yearChip("Any", value: nil)
                yearChip("2024", value: "2024")
                yearChip("2023", value: "2023")
                yearChip("2020s", value: "2020")
            }

            Slider(
                value: $sliderYear,
                in: Double(FiltersConstants.minYear)...Double(FiltersConstants.maxYear),
                step: 1
            )
            .tint(.red)
            .onChange(of: sliderYear) { _, newValue in
                selectedYear = String(Int(newValue))
            }

            HStack {
                Text(String(FiltersConstants.minYear))
                Spacer()
                Text(String(FiltersConstants.maxYear))
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white.opacity(0.42))
        }
    }

    private var dateRangeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Date Range")

            HStack(spacing: 14) {
                dateCard(
                    title: "FROM",
                    selectedDate: hasFromDate ? fromDate : nil,
                    action: { hasFromDate.toggle() }
                )
                dateCard(
                    title: "TO",
                    selectedDate: hasToDate ? toDate : nil,
                    action: { hasToDate.toggle() }
                )
            }

            if hasFromDate {
                DatePicker(
                    "From",
                    selection: $fromDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .colorScheme(.dark)
            }

            if hasToDate {
                DatePicker(
                    "To",
                    selection: $toDate,
                    in: fromDate...,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .colorScheme(.dark)
            }
        }
    }

    private var applyButton: some View {
        Button {
            onApply(
                title,
                selectedYear,
                hasFromDate ? fromDate : nil,
                hasToDate ? toDate : nil
            )
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Text("Apply Filters")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                Text(resultCountLabel)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.red)
            )
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(Color.black.opacity(0.55))
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(.white)
    }

    private func yearChip(_ title: String, value: String?) -> some View {
        let isSelected = selectedYear == value
        return Button {
            selectedYear = value
            if let value, let numeric = Double(value) {
                sliderYear = numeric
            }
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(isSelected ? 1 : 0.8))
                .padding(.horizontal, 22)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? Color.red : Color.white.opacity(0.09))
                )
        }
    }

    private func dateCard(title: String, selectedDate: Date?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))

                HStack(spacing: 8) {
                    Text(selectedDate.map { FiltersConstants.dateFormatter.string(from: $0) } ?? "Select Date")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(.white.opacity(selectedDate == nil ? 0.6 : 0.95))
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "calendar")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white.opacity(0.78))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, minHeight: 94)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
    }

    private var selectedYearBadge: String {
        selectedYear ?? "Any"
    }

    private var resultCountLabel: String {
        "Results"
    }

    private func configureInitialValues() {
        title = initialTitle
        selectedYear = initialSelectedYear

        if let year = initialSelectedYear, let numericYear = Double(year) {
            sliderYear = numericYear
        } else {
            sliderYear = Double(FiltersConstants.maxYear)
        }

        if let initialFromDate {
            fromDate = initialFromDate
            hasFromDate = true
        } else {
            hasFromDate = false
        }

        if let initialToDate {
            toDate = initialToDate
            hasToDate = true
        } else {
            hasToDate = false
        }
    }

    private func resetAll() {
        title = ""
        selectedYear = nil
        sliderYear = Double(FiltersConstants.maxYear)
        fromDate = Date()
        toDate = Date()
        hasFromDate = false
        hasToDate = false
    }
}

private enum FiltersConstants {
    static let minYear = 1920
    static let maxYear = Calendar.current.component(.year, from: Date())
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()
}

