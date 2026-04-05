import Testing
import Foundation
@testable import SlopTemplates
import SlopKit

// MARK: - BuiltInTemplateRegistry Tests

@Test
func registryIncludesExpandedBaselineCatalog() {
    #expect(BuiltInTemplateRegistry.all.count >= 61)
    #expect(BuiltInTemplateRegistry.resolve(templateID: "com.hitslop.templates.daily-planner") != nil)
    #expect(BuiltInTemplateRegistry.resolve(templateID: "com.hitslop.templates.weekly-review") != nil)
    #expect(BuiltInTemplateRegistry.resolve(templateID: "com.hitslop.templates.portfolio-allocator") != nil)
    #expect(BuiltInTemplateRegistry.resolve(templateID: "com.hitslop.templates.sleep-tracker") != nil)
}

@Test
func resolveByIDFindsKnownTemplate() {
    let found = BuiltInTemplateRegistry.resolve(templateID: "com.hitslop.templates.budget-tracker")
    #expect(found != nil)
    #expect(found?.templateID == "com.hitslop.templates.budget-tracker")
}

@Test
func resolveByIDReturnsNilForUnknown() {
    let found = BuiltInTemplateRegistry.resolve(templateID: "com.bogus.nonexistent")
    #expect(found == nil)
}

@Test
func resolveByIDAndVersionMatches() {
    let found = BuiltInTemplateRegistry.resolve(
        templateID: "com.hitslop.templates.budget-tracker",
        version: "2.0.0"
    )
    #expect(found != nil)
}

@Test
func resolveByIDAndVersionReturnsNilForWrongVersion() {
    let found = BuiltInTemplateRegistry.resolve(
        templateID: "com.hitslop.templates.budget-tracker",
        version: "99.0.0"
    )
    #expect(found == nil)
}

// MARK: - Manifest Generation Tests

@Test
func manifestForTemplateHasCorrectID() {
    let type = BuiltInTemplateRegistry.all.first!
    let manifest = BuiltInTemplateRegistry.manifest(for: type)
    #expect(manifest.id == type.templateID)
}

@Test
func manifestForTemplateHasSchema() {
    let type = BuiltInTemplateRegistry.all.first!
    let manifest = BuiltInTemplateRegistry.manifest(for: type)
    #expect(!manifest.schema.allFields.isEmpty)
}

@Test
func manifestForTemplateHasMetadata() {
    let type = BuiltInTemplateRegistry.all.first!
    let manifest = BuiltInTemplateRegistry.manifest(for: type)
    #expect(manifest.metadata.width > 0)
}

@Test
func allBuiltInTemplatesExposeDescriptions() {
    for type in BuiltInTemplateRegistry.all {
        #expect(type.templateDescription?.isEmpty == false)
    }
}

// MARK: - Template Data Computed Properties

@Test
func budgetTotalExpensesComputesSum() {
    let data = BudgetData(from: [
        "title": .string("Test Budget"),
        "currency": .string("USD"),
        "income": .number(5000),
        "categories": .array([
            .record([
                "id": .string("cat1"),
                "name": .string("Food"),
                "color": .string("#ff0000"),
                "items": .array([
                    .record(["id": .string("a"), "name": .string("Groceries"), "amount": .number(100)]),
                    .record(["id": .string("b"), "name": .string("Dining"), "amount": .number(50)]),
                ]),
            ]),
        ]),
    ])
    #expect(data.totalExpenses == 150)
}

@Test
func budgetRemainingIsIncomeMinusExpenses() {
    let data = BudgetData(from: [
        "title": .string("Test Budget"),
        "currency": .string("USD"),
        "income": .number(5000),
        "categories": .array([
            .record([
                "id": .string("cat1"),
                "name": .string("Housing"),
                "color": .string("#0000ff"),
                "items": .array([
                    .record(["id": .string("a"), "name": .string("Rent"), "amount": .number(1500)]),
                ]),
            ]),
        ]),
    ])
    #expect(data.remaining == 3500)
}

@Test
func budgetDefaultCategoriesNonEmpty() {
    #expect(!BudgetData.defaultCategories.isEmpty)
}

@Test
func allTemplateIDsAreUnique() {
    let ids = BuiltInTemplateRegistry.all.map { $0.templateID }
    let uniqueIDs = Set(ids)
    #expect(ids.count == uniqueIDs.count)
}
