//
//  StarsSelector.swift
//  Plugin Reporter
//
//  Rating selector component with visual star icons
//

import SwiftUI

struct StarsSelector: View {
    @Binding var selectedStarRatings: Set<Int>

    private func toggle(rating: Int) {
        if selectedStarRatings.contains(rating) {
            selectedStarRatings.remove(rating)
        } else {
            selectedStarRatings.insert(rating)
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            // Display stars from 5 down to 1
            ForEach([5, 4, 3, 2, 1], id: \.self) { rating in
                starRow(rating: rating)
            }
        }
    }

    @ViewBuilder private func starRow(rating: Int) -> some View {
        let isSelected = selectedStarRatings.contains(rating)
        Button(action: { toggle(rating: rating) }) {
            HStack(spacing: 3) {
                ForEach(1...rating, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 11.2))
                        .foregroundColor(.yellow)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.yellow : Color.clear, lineWidth: isSelected ? 2 : 0)
            )
        }
        .buttonStyle(.plain)
    }
}
