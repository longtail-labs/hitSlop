import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct RecipeIngredient: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Ingredient") var name: String = ""
    @Field("Ready") var isReady: Bool = false
}

@SlopData
public struct RecipeStep: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Step Title") var title: String = ""
    @Field("Details") var detail: String = ""
}

@SlopData
public struct RecipeData {
    @SlopKit.Section("Overview") @Field("Recipe Name") var title: String = "Pasta Carbonara"
    @Field("Subtitle") var subtitle: String = "Classic Roman pasta with eggs, cheese, and guanciale"
    @Field("Photo") var photo: TemplateImage = TemplateImage("")
    @Field("Prep Minutes") var prepMinutes: Double = 10
    @Field("Cook Minutes") var cookMinutes: Double = 20
    @Field("Serves") var serves: Double = 4

    @SlopKit.Section("Ingredients") @Field("Ingredients") var ingredients: [RecipeIngredient] = RecipeData.defaultIngredients
    @SlopKit.Section("Steps") @Field("Steps") var steps: [RecipeStep] = RecipeData.defaultSteps
    @SlopKit.Section("Notes") @Field("Tip") var tip: String = "Never add cream to a real carbonara."

    var readyCount: Int { ingredients.filter(\.isReady).count }
}

extension RecipeData {
    static var defaultIngredients: [RecipeIngredient] {
        func ingredient(_ name: String, _ ready: Bool) -> RecipeIngredient {
            var value = RecipeIngredient()
            value.name = name
            value.isReady = ready
            return value
        }

        return [
            ingredient("400g spaghetti", false),
            ingredient("200g guanciale", false),
            ingredient("4 egg yolks", true),
            ingredient("100g Pecorino Romano", true),
            ingredient("Black pepper", true),
        ]
    }

    static var defaultSteps: [RecipeStep] {
        func step(_ title: String, _ detail: String) -> RecipeStep {
            var value = RecipeStep()
            value.title = title
            value.detail = detail
            return value
        }

        return [
            step("Boil water", "Bring a large pot of salted water to a rolling boil."),
            step("Cook guanciale", "Start in a cold pan and render until crispy."),
            step("Mix eggs and cheese", "Whisk yolks and grated Pecorino until thick."),
            step("Cook pasta", "Stop 1 minute short of al dente."),
            step("Combine", "Toss off heat with guanciale, then work in the egg mixture quickly."),
        ]
    }
}

// MARK: - Template

@SlopTemplate(
    id: "com.hitslop.templates.recipe",
    name: "Recipe Card",
    description: "Store ingredients and cooking steps in a clean kitchen-friendly layout.",
    version: "1.0.0",
    width: 460, height: 620,
    minWidth: 380, minHeight: 500,
    shape: .roundedRect(radius: 22),
    theme: "rose",
    alwaysOnTop: true,
    categories: ["personal"]
)
struct RecipeView: View {
    @TemplateData var data: RecipeData
    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget

    var body: some View {
        Group {
            if renderTarget == .interactive {
                ScrollView(showsIndicators: false) { interactiveContent }
            } else {
                exportContent
            }
        }
        .background(theme.background)
    }

    private var interactiveContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Hero photo
            if !data.photo.path.isEmpty {
                SlopImage(image: $data.photo, placeholder: "Add photo")
                    .frame(maxHeight: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                SlopImage(image: $data.photo, placeholder: "Add photo")
                    .frame(height: 60)
            }

            VStack(alignment: .leading, spacing: 8) {
                SlopTextField("Recipe Name", text: $data.title)
                    .font(theme.title(size: 28))
                    .foregroundStyle(theme.foreground)
                SlopTextField("Description", text: $data.subtitle)
                    .foregroundStyle(theme.secondary)
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Text("Prep")
                            .foregroundStyle(theme.background)
                        SlopNumberField("0", value: $data.prepMinutes)
                            .foregroundStyle(theme.background)
                            .frame(width: 24)
                        Text("min")
                            .foregroundStyle(theme.background)
                    }
                    .font(theme.mono(size: 10, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(theme.accent))

                    HStack(spacing: 4) {
                        Text("Cook")
                            .foregroundStyle(theme.background)
                        SlopNumberField("0", value: $data.cookMinutes)
                            .foregroundStyle(theme.background)
                            .frame(width: 24)
                        Text("min")
                            .foregroundStyle(theme.background)
                    }
                    .font(theme.mono(size: 10, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(theme.accent))

                    HStack(spacing: 4) {
                        Text("Serves")
                            .foregroundStyle(theme.background)
                        SlopNumberField("0", value: $data.serves)
                            .foregroundStyle(theme.background)
                            .frame(width: 18)
                    }
                    .font(theme.mono(size: 10, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(theme.accent))
                }
            }

            Divider().background(theme.divider)

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Ingredients")
                        .font(theme.mono(size: 11, weight: .bold))
                        .foregroundStyle(theme.secondary)
                    Text("\(data.readyCount) / \(data.ingredients.count) ready")
                        .font(theme.font(size: 13, weight: .semibold))
                        .foregroundStyle(theme.accent)

                    ForEach($data.ingredients) { $ingredient in
                        HStack(spacing: 10) {
                            SlopInteractiveOnly {
                                Button {
                                    withAnimation { ingredient.isReady.toggle() }
                                } label: {
                                    Image(systemName: ingredient.isReady ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(ingredient.isReady ? theme.accent : theme.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            SlopTextField("Ingredient", text: $ingredient.name)
                                .foregroundStyle(theme.foreground.opacity(ingredient.isReady ? 0.95 : 0.8))
                            SlopInteractiveOnly {
                                Button {
                                    withAnimation { data.ingredients.removeAll { $0.id == ingredient.id } }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(theme.font(size: 10))
                                        .foregroundStyle(theme.secondary.opacity(0.3))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    SlopInteractiveOnly {
                        Button {
                            withAnimation { data.ingredients.append(RecipeIngredient()) }
                        } label: {
                            Label("Add", systemImage: "plus")
                                .font(.caption)
                                .foregroundStyle(theme.secondary.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: 160, alignment: .topLeading)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Steps")
                        .font(theme.mono(size: 11, weight: .bold))
                        .foregroundStyle(theme.secondary)
                    ForEach(Array($data.steps.enumerated()), id: \.element.id) { index, $step in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(spacing: 4) {
                                    Text("\(index + 1).")
                                        .font(theme.font(size: 14, weight: .semibold))
                                        .foregroundStyle(theme.foreground)
                                    SlopTextField("Step", text: $step.title)
                                        .font(theme.font(size: 14, weight: .semibold))
                                        .foregroundStyle(theme.foreground)
                                }
                                SlopTextField("Details", text: $step.detail)
                                    .foregroundStyle(theme.secondary)
                            }
                            SlopInteractiveOnly {
                                Button {
                                    withAnimation { data.steps.removeAll { $0.id == step.id } }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(theme.font(size: 10))
                                        .foregroundStyle(theme.secondary.opacity(0.3))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    SlopInteractiveOnly {
                        Button {
                            withAnimation { data.steps.append(RecipeStep()) }
                        } label: {
                            Label("Add Step", systemImage: "plus")
                                .font(.caption)
                                .foregroundStyle(theme.secondary.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Divider().background(theme.divider)

            SlopTextField("Tip", text: $data.tip)
                .font(theme.font(size: 12, weight: .medium))
                .foregroundStyle(theme.accent)
        }
        .padding(24)
    }

    private var exportContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !data.photo.path.isEmpty {
                SlopImage(image: $data.photo, placeholder: "")
                    .frame(maxHeight: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(data.title)
                    .font(theme.title(size: 28))
                    .foregroundStyle(theme.foreground)
                Text(data.subtitle)
                    .foregroundStyle(theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    statBadge("Prep \(Int(data.prepMinutes)) min")
                    statBadge("Cook \(Int(data.cookMinutes)) min")
                    statBadge("Serves \(Int(data.serves))")
                }
            }

            Divider().background(theme.divider)

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Ingredients")
                        .font(theme.mono(size: 11, weight: .bold))
                        .foregroundStyle(theme.secondary)
                    Text("\(data.readyCount) / \(data.ingredients.count) ready")
                        .font(theme.font(size: 13, weight: .semibold))
                        .foregroundStyle(theme.accent)

                    ForEach(data.ingredients) { ingredient in
                        HStack(spacing: 10) {
                            Image(systemName: ingredient.isReady ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(ingredient.isReady ? theme.accent : theme.secondary)
                            Text(ingredient.name)
                                .foregroundStyle(theme.foreground.opacity(ingredient.isReady ? 0.95 : 0.8))
                        }
                    }
                }
                .frame(maxWidth: 160, alignment: .topLeading)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Steps")
                        .font(theme.mono(size: 11, weight: .bold))
                        .foregroundStyle(theme.secondary)
                    ForEach(Array(data.steps.enumerated()), id: \.element.id) { index, step in
                        VStack(alignment: .leading, spacing: 5) {
                            Text("\(index + 1). \(step.title)")
                                .font(theme.font(size: 14, weight: .semibold))
                                .foregroundStyle(theme.foreground)
                            Text(step.detail)
                                .foregroundStyle(theme.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            Divider().background(theme.divider)

            Text(data.tip)
                .font(theme.font(size: 12, weight: .medium))
                .foregroundStyle(theme.accent)
        }
        .padding(24)
    }

    private func statBadge(_ value: String) -> some View {
        Text(value)
            .font(theme.mono(size: 10, weight: .bold))
            .foregroundStyle(theme.background)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Capsule().fill(theme.accent))
    }
}

