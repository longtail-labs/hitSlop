import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct FlashCard: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Front") var front: String = ""
    @Field("Back") var back: String = ""
    @Field("Difficulty") var difficulty: Double = 0
    @Field("Last Reviewed") var lastReviewed: String = ""
}

extension FlashCardData {
    static var defaultCards: [FlashCard] {
        func card(_ front: String, _ back: String) -> FlashCard {
            var c = FlashCard()
            c.front = front
            c.back = back
            return c
        }
        return [
            card("Mitochondria", "Powerhouse of the cell"),
            card("DNA", "Deoxyribonucleic acid - carries genetic information"),
            card("Photosynthesis", "Process by which plants convert light energy into chemical energy"),
            card("Cell Membrane", "Semi-permeable barrier that controls what enters and exits the cell")
        ]
    }
}

@SlopData
public struct FlashCardData {
    @SlopKit.Section("Deck")
    @Field("Deck Title") var deckTitle: String = "Study Deck"
    @Field("Cards") var cards: [FlashCard] = FlashCardData.defaultCards

    var masteredCount: Int {
        cards.filter { $0.difficulty >= 4 }.count
    }

    var totalCards: Int {
        cards.count
    }
}

@SlopTemplate(
    id: "com.hitslop.templates.flash-cards",
    name: "Flash Cards",
    description: "Study with interactive flash cards featuring spaced repetition difficulty ratings.",
    version: "1.0.0",
    width: 400, height: 500,
    shape: .roundedRect(radius: 16),
    alwaysOnTop: true,
    categories: ["education"]
)
struct FlashCardView: View {
    @TemplateData var data: FlashCardData
    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget

    @State private var currentIndex: Int = 0
    @State private var isFlipped: Bool = false

    var body: some View {
        SlopContent {
            if renderTarget == .interactive {
                interactiveView
            } else {
                exportView
            }
        }
        .background(theme.background)
    }

    @ViewBuilder
    private var interactiveView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                SlopTextField("Deck Title", text: $data.deckTitle)
                    .font(theme.titleFont)
                    .foregroundColor(theme.foreground)

                if !data.cards.isEmpty {
                    Text("Card \(currentIndex + 1) of \(data.totalCards)")
                        .font(theme.bodyFont)
                        .foregroundColor(theme.secondary)
                }
            }

            if data.cards.isEmpty {
                VStack(spacing: 16) {
                    Text("No cards yet")
                        .font(theme.bodyFont)
                        .foregroundColor(theme.secondary)

                    SlopInteractiveOnly {
                        Button(action: addCard) {
                            Label("Add Card", systemImage: "plus.circle.fill")
                                .font(theme.bodyFont)
                                .foregroundColor(theme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Card display
                SlopInteractiveOnly {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isFlipped.toggle()
                        }
                    }) {
                        cardView
                    }
                    .buttonStyle(.plain)
                }

                // Difficulty buttons
                SlopInteractiveOnly {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            difficultyButton(title: "Again", difficulty: 1, color: .red)
                            difficultyButton(title: "Hard", difficulty: 2, color: .orange)
                            difficultyButton(title: "Good", difficulty: 3, color: .blue)
                            difficultyButton(title: "Easy", difficulty: 5, color: .green)
                        }

                        // Progress bar
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Mastered: \(data.masteredCount) / \(data.totalCards)")
                                    .font(.caption)
                                    .foregroundColor(theme.secondary)
                                Spacer()
                                Text("\(Int(Double(data.masteredCount) / Double(max(data.totalCards, 1)) * 100))%")
                                    .font(.caption)
                                    .foregroundColor(theme.secondary)
                            }

                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(theme.surface)
                                        .frame(height: 6)
                                        .cornerRadius(3)

                                    Rectangle()
                                        .fill(theme.accent)
                                        .frame(width: geometry.size.width * CGFloat(data.masteredCount) / CGFloat(max(data.totalCards, 1)), height: 6)
                                        .cornerRadius(3)
                                }
                            }
                            .frame(height: 6)
                        }

                        Button(action: addCard) {
                            Label("Add Card", systemImage: "plus.circle.fill")
                                .font(theme.bodyFont)
                                .foregroundColor(theme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(24)
    }

    @ViewBuilder
    private var cardView: some View {
        let currentCard = data.cards.indices.contains(currentIndex) ? data.cards[currentIndex] : nil

        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isFlipped ? Color.green.opacity(0.5) : theme.accent.opacity(0.5), lineWidth: 2)
                )

            VStack(spacing: 12) {
                Text(isFlipped ? "Answer" : "Question")
                    .font(.caption)
                    .foregroundColor(theme.secondary)

                if let card = currentCard {
                    Text(isFlipped ? card.back : card.front)
                        .font(.title3)
                        .foregroundColor(theme.foreground)
                        .multilineTextAlignment(.center)
                        .padding()
                }

                Text("Tap to flip")
                    .font(.caption2)
                    .foregroundColor(theme.secondary.opacity(0.6))
            }
            .padding()
            .id(isFlipped)
        }
        .frame(height: 200)
    }

    @ViewBuilder
    private func difficultyButton(title: String, difficulty: Double, color: Color) -> some View {
        Button(action: {
            rateCard(difficulty: difficulty)
        }) {
            Text(title)
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(color)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var exportView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(data.deckTitle)
                .font(theme.titleFont)
                .foregroundColor(theme.foreground)

            let columns = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(data.cards) { card in
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Q:")
                                .font(.caption)
                                .foregroundColor(theme.accent)
                            Text(card.front)
                                .font(theme.bodyFont)
                                .foregroundColor(theme.foreground)
                        }

                        Divider()
                            .background(theme.divider)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("A:")
                                .font(.caption)
                                .foregroundColor(Color.green)
                            Text(card.back)
                                .font(theme.bodyFont)
                                .foregroundColor(theme.foreground)
                        }
                    }
                    .padding(12)
                    .background(theme.surface)
                    .cornerRadius(8)
                }
            }
        }
        .padding(24)
    }

    private func addCard() {
        var newCard = FlashCard()
        newCard.front = "Question"
        newCard.back = "Answer"
        data.cards.append(newCard)
        currentIndex = data.cards.count - 1
        isFlipped = false
    }

    private func rateCard(difficulty: Double) {
        guard data.cards.indices.contains(currentIndex) else { return }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        data.cards[currentIndex].difficulty = difficulty
        data.cards[currentIndex].lastReviewed = dateFormatter.string(from: Date())

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isFlipped = false
            if currentIndex < data.cards.count - 1 {
                currentIndex += 1
            } else {
                currentIndex = 0
            }
        }
    }
}
