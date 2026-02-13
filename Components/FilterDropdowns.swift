//
//  FilterDropdowns.swift
//  Plugin Reporter
//
//  Reusable dropdown components for Publisher and Style filtering
//

import SwiftUI

// MARK: - Publisher Dropdown

struct PublisherDropdown: View {
    let allPublishers: [String]
    @Binding var selectedPublishers: Set<String>
    @State private var showingPopover = false

    private var displayText: String {
        if selectedPublishers.isEmpty {
            return "All Publishers"
        } else if selectedPublishers.count == 1 {
            return selectedPublishers.first ?? "All Publishers"
        } else {
            return "\(selectedPublishers.count) Publishers"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Menu {
                Button("All Publishers") {
                    selectedPublishers.removeAll()
                }

                Divider()

                ForEach(allPublishers.filter { !$0.isEmpty }, id: \.self) { publisher in
                    Button(action: {
                        if selectedPublishers.contains(publisher) {
                            selectedPublishers.remove(publisher)
                        } else {
                            selectedPublishers.insert(publisher)
                        }
                    }) {
                        HStack {
                            Text(publisher)
                            Spacer()
                            if selectedPublishers.contains(publisher) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(displayText)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)
            .frame(maxWidth: .infinity)

            if !selectedPublishers.isEmpty {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], alignment: .leading, spacing: 4) {
                        ForEach(Array(selectedPublishers).sorted(), id: \.self) { publisher in
                            HStack {
                                Text(publisher)
                                    .font(.caption2)
                                    .lineLimit(1)
                                Spacer(minLength: 2)
                                Button(action: {
                                    selectedPublishers.remove(publisher)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.15))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 0.5)
                            )
                        }
                    }
                }
                .frame(maxHeight: 80)
            }
        }
    }
}

// MARK: - Style Dropdown

struct StyleDropdown: View {
    let allStyles: [String]
    @Binding var selectedStyles: Set<String>
    @State private var showingPopover = false

    private var displayText: String {
        if selectedStyles.isEmpty {
            return "All Styles"
        } else if selectedStyles.count == 1 {
            return selectedStyles.first ?? "All Styles"
        } else {
            return "\(selectedStyles.count) Styles"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Menu {
                Button("All Styles") {
                    selectedStyles.removeAll()
                }

                Divider()

                ForEach(allStyles.filter { !$0.isEmpty }, id: \.self) { style in
                    Button(action: {
                        if selectedStyles.contains(style) {
                            selectedStyles.remove(style)
                        } else {
                            selectedStyles.insert(style)
                        }
                    }) {
                        HStack {
                            Text(style)
                            Spacer()
                            if selectedStyles.contains(style) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(displayText)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)
            .frame(maxWidth: .infinity)

            if !selectedStyles.isEmpty {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], alignment: .leading, spacing: 4) {
                        ForEach(Array(selectedStyles).sorted(), id: \.self) { style in
                            HStack {
                                Text(style)
                                    .font(.caption2)
                                    .lineLimit(1)
                                Spacer(minLength: 2)
                                Button(action: {
                                    selectedStyles.remove(style)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.15))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 0.5)
                            )
                        }
                    }
                }
                .frame(maxHeight: 80)
            }
        }
    }
}
