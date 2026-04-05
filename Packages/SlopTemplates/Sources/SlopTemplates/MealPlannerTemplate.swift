import Foundation
import SwiftUI
import SlopKit

// MARK: - Data Model

@SlopData
public struct GroceryItem: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Name") var name: String = ""
    @Field("Done") var isDone: Bool = false
}

@SlopData
public struct DayPlan: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Day") var day: String = ""
    @Field("Breakfast") var breakfast: String = ""
    @Field("Lunch") var lunch: String = ""
    @Field("Dinner") var dinner: String = ""
}

@SlopData
public struct MealPlannerData {
    @SlopKit.Section("Overview") @Field("Title") var title: String = "Weekly Meals"
    @Field("Week Of") var weekOf: Date = .now

    @SlopKit.Section("Meals") @Field("Days") var days: [DayPlan] = MealPlannerData.defaultDays

    @SlopKit.Section("Groceries") @Field("Groceries") var groceries: [GroceryItem] = MealPlannerData.defaultGroceries

    var groceriesDone: Int { groceries.filter(\.isDone).count }
}

extension MealPlannerData {
    static var defaultDays: [DayPlan] {
        func day(_ name: String, _ breakfast: String, _ lunch: String, _ dinner: String) -> DayPlan {
            var d = DayPlan()
            d.day = name
            d.breakfast = breakfast
            d.lunch = lunch
            d.dinner = dinner
            return d
        }

        return [
            day("Monday", "Oatmeal & fruit", "Grilled chicken salad", "Pasta carbonara"),
            day("Tuesday", "Scrambled eggs & toast", "Turkey wrap", "Stir-fry vegetables & rice"),
            day("Wednesday", "Yogurt & granola", "Tomato soup & bread", "Baked salmon & greens"),
            day("Thursday", "Smoothie bowl", "Caesar salad", "Chicken tikka masala"),
            day("Friday", "Pancakes & berries", "Poke bowl", "Homemade pizza"),
            day("Saturday", "Avocado toast", "Grilled cheese & soup", "Beef tacos"),
            day("Sunday", "French toast", "Pasta salad", "Roast chicken & potatoes"),
        ]
    }

    static var defaultGroceries: [GroceryItem] {
        func item(_ name: String) -> GroceryItem {
            var g = GroceryItem()
            g.name = name
            return g
        }

        return [
            item("Eggs"),
            item("Chicken breast"),
            item("Pasta"),
            item("Mixed greens"),
            item("Olive oil"),
        ]
    }
}

// MARK: - Template

@SlopTemplate(
    id: "com.hitslop.templates.meal-planner",
    name: "Meal Planner",
    description: "Plan meals for the week with dishes, times, and quick prep notes.",
    version: "1.0.0",
    width: 480, height: 580,
    minWidth: 400, minHeight: 460,
    shape: .roundedRect(radius: 18),
    theme: "forest",
    alwaysOnTop: true,
    categories: ["health"]
)
struct MealPlannerView: View {
    @TemplateData var data: MealPlannerData
    @Environment(\.slopTheme) private var theme

    private static func makeDate(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d)) ?? .now
    }

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 16) {
                // Title & week label
                SlopTextField("Meal Plan Title", text: $data.title)
                    .font(theme.title(size: 22))
                    .foregroundStyle(theme.foreground)

                SlopEditable($data.weekOf) { value in
                    Text("Week of \(value.formatted(date: .abbreviated, time: .omitted))")
                        .font(.subheadline)
                        .foregroundStyle(theme.secondary)
                } editor: { $value in
                    DatePicker("Week of", selection: $value, displayedComponents: .date)
                        .labelsHidden()
                }

                Divider().background(theme.divider)

                // Meal grid header
                mealGridHeader

                // Day rows
                ForEach($data.days) { $day in
                    mealRow(day: $day)
                }

                Divider().background(theme.divider)

                // Grocery checklist
                SectionHeader("Groceries")

                ForEach($data.groceries) { $item in
                    HStack(spacing: 8) {
                        CheckmarkIndicator(isChecked: $item.isDone)

                        SlopTextField("Item name", text: $item.name)
                            .foregroundStyle(item.isDone ? theme.secondary.opacity(0.5) : theme.foreground.opacity(0.8))
                            .strikethrough(item.isDone)

                        Spacer()

                        RemoveButton {
                            withAnimation {
                                data.groceries.removeAll { $0.id == item.id }
                            }
                        }
                    }
                }

                AddItemButton("Add Grocery Item") {
                    withAnimation {
                        data.groceries.append(GroceryItem())
                    }
                }

                Text("\(data.groceriesDone) / \(data.groceries.count) items")
                    .font(.caption)
                    .foregroundStyle(theme.accent)
            }
            .padding(24)
        }
        .background(theme.background)
    }

    private var mealGridHeader: some View {
        HStack(spacing: 0) {
            Text("Day")
                .frame(width: 70, alignment: .leading)
            Text("Breakfast")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Lunch")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Dinner")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.caption.monospaced().weight(.medium))
        .foregroundStyle(theme.secondary)
    }

    private func mealRow(day: Binding<DayPlan>) -> some View {
        HStack(spacing: 0) {
            Text(day.wrappedValue.day)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.foreground)
                .frame(width: 70, alignment: .leading)

            SlopTextField("Breakfast", text: day.breakfast)
                .font(.caption)
                .foregroundStyle(theme.foreground.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)

            SlopTextField("Lunch", text: day.lunch)
                .font(.caption)
                .foregroundStyle(theme.foreground.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)

            SlopTextField("Dinner", text: day.dinner)
                .font(.caption)
                .foregroundStyle(theme.foreground.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

