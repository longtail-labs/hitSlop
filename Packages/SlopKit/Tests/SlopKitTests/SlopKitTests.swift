import SwiftUI
import Combine
import Testing
@testable import SlopKit

@SlopData
public struct TestLineItem {
    @Field("Description") var description: String = ""
    @Field("Qty") var qty: Int = 1
}

@SlopData
public struct TestAddress {
    @Field("Street") var street: String = ""
    @Field("Zip") var zip: Int = 90210
}

@SlopData
public struct TestTemplateData {
    @SlopKit.Section("Company")
    @Field("Name") var name: String = "Acme"
    @Field("Accent Color") var accentColor: HexColor = "#123456"

    @SlopKit.Section("Options")
    @Field("Enabled") var enabled: Bool = true
    @Field("Due Date") var dueDate: Date = Date(timeIntervalSince1970: 1_700_000_000)
    @Field("Logo") var logo: TemplateImage? = TemplateImage("/tmp/logo.png")
    @Field("Currency", options: ["USD", "EUR"]) var currency: String = "USD"
    @Field("Amount", editor: .currency(codeField: "currency")) var amount: Double = 42.5
    @Field("Tags", editor: .stringList) var tags: [String] = ["alpha", "beta"]

    @SlopKit.Section("Items")
    @Field("Items", constraints: [.minItems(1)]) var items: [TestLineItem] = [TestLineItem()]

    @SlopKit.Section("Address")
    @Field("Address") var address: TestAddress = TestAddress()
}

private final class DummyTemplate: AnySlopTemplate {
    static let templateID = "com.hitslop.tests.dummy"
    static let name = "Dummy"
    static let templateDescription: String? = "A test template used to verify manifest serialization."
    static let version = "1.2.3"
    static let minimumHostVersion = "1.0.0"
    static let schema = TestTemplateData.schema
    static let metadata = TemplateMetadata(
        width: 420,
        height: 320,
        windowShape: .roundedRect(radius: 20),
        theme: "ocean",
        alwaysOnTop: false,
        titleBarHidden: true
    )

    required init(rawStore: RawTemplateStore) {}

    @MainActor
    func body() -> AnyView {
        AnyView(EmptyView())
    }
}

@Test
func macroGeneratedSchemaIncludesSectionsOptionsArraysAndRecords() {
    let schema = TestTemplateData.schema

    #expect(schema.sections.map(\.title) == ["Company", "Options", "Items", "Address"])

    let nameField = schema.field(forKey: "name")
    #expect(nameField?.kind == .string)
    #expect(nameField?.defaultValue == .string("Acme"))

    let currencyField = schema.field(forKey: "currency")
    #expect(currencyField?.kind == .enumeration)
    #expect(currencyField?.options?.map(\.value) == ["USD", "EUR"])
    #expect(currencyField?.resolvedEditor == .enumeration)

    let amountField = schema.field(forKey: "amount")
    #expect(amountField?.kind == .number)
    #expect(amountField?.editor == .currency(codeField: "currency"))

    let itemsField = schema.field(forKey: "items")
    #expect(itemsField?.kind == .array)
    #expect(itemsField?.constraints == [.minItems(1)])
    #expect(itemsField?.itemSchema?.field(forKey: "description")?.kind == .string)

    let tagsField = schema.field(forKey: "tags")
    #expect(tagsField?.kind == .array)
    #expect(tagsField?.arrayItemKind == .string)
    #expect(tagsField?.resolvedEditor == .stringList)

    let addressField = schema.field(forKey: "address")
    #expect(addressField?.kind == .record)
    #expect(addressField?.recordSchema?.field(forKey: "zip")?.kind == .number)
}

@Test
func templateDataRoundTripsThroughFieldValues() {
    let values: [String: FieldValue] = [
        "name": .string("Globex"),
        "accentColor": .color("#abcdef"),
        "enabled": .bool(false),
        "dueDate": .date(Date(timeIntervalSince1970: 1_700_000_100)),
        "logo": .image("/tmp/custom.png"),
        "currency": .string("EUR"),
        "amount": .number(125.5),
        "tags": .array([.string("research"), .string("finance")]),
        "items": .array([
            .record([
                "description": .string("Hosting"),
                "qty": .number(3),
            ])
        ]),
        "address": .record([
            "street": .string("Main"),
            "zip": .number(12345),
        ]),
    ]

    let data = TestTemplateData(from: values)
    let encoded = data.toFieldValues()

    #expect(encoded["name"] == .string("Globex"))
    #expect(encoded["accentColor"] == .color("#abcdef"))
    #expect(encoded["enabled"] == .bool(false))
    #expect(encoded["currency"] == .string("EUR"))
    #expect(encoded["logo"] == .image("/tmp/custom.png"))
    #expect(encoded["amount"] == .number(125.5))
    #expect(encoded["tags"] == .array([.string("research"), .string("finance")]))

    let items = encoded["items"]?.asArray ?? []
    #expect(items.count == 1)
    #expect(items.first?.asRecord?["description"] == .string("Hosting"))

    let address = encoded["address"]?.asRecord
    #expect(address?["street"] == .string("Main"))
    #expect(address?["zip"] == .number(12345))
}

@Test
func fieldValueSchemaGuidedRoundTripPreservesTypedValues() {
    let schema = Schema(sections: [
        SchemaSection("General", fields: [
            FieldDescriptor(key: "title", label: "Title", kind: .string, defaultValue: .string("Untitled")),
            FieldDescriptor(key: "accent", label: "Accent", kind: .color, defaultValue: .color("#111111")),
            FieldDescriptor(key: "when", label: "When", kind: .date, defaultValue: .date(Date(timeIntervalSince1970: 0))),
            FieldDescriptor(key: "logo", label: "Logo", kind: .image, defaultValue: .image("/tmp/default.png")),
            FieldDescriptor(
                key: "tags",
                label: "Tags",
                kind: .array,
                defaultValue: .array([]),
                arrayItemKind: .string,
                editor: .stringList
            ),
            FieldDescriptor(
                key: "items",
                label: "Items",
                kind: .array,
                defaultValue: .array([]),
                itemSchema: Schema(sections: [
                    SchemaSection("Item", fields: [
                        FieldDescriptor(key: "label", label: "Label", kind: .string, defaultValue: .string("")),
                    ])
                ])
            ),
            FieldDescriptor(
                key: "profile",
                label: "Profile",
                kind: .record,
                defaultValue: .record([:]),
                recordSchema: Schema(sections: [
                    SchemaSection("Profile", fields: [
                        FieldDescriptor(key: "name", label: "Name", kind: .string, defaultValue: .string("")),
                    ])
                ])
            ),
        ])
    ])

    let date = Date(timeIntervalSince1970: 1_700_000_000)
    let values: [String: FieldValue] = [
        "title": .string("Budget"),
        "accent": .color("#ff00ff"),
        "when": .date(date),
        "logo": .image("/tmp/logo.png"),
        "tags": .array([.string("One"), .string("Two")]),
        "items": .array([.record(["label": .string("One")])]),
        "profile": .record(["name": .string("Jordan")]),
    ]

    let raw = FieldValue.encodeRecord(values, schema: schema)
    let decoded = FieldValue.decodeRecord(raw, schema: schema)

    #expect(decoded["title"] == .string("Budget"))
    #expect(decoded["accent"] == .color("#ff00ff"))
    #expect(decoded["logo"] == .image("/tmp/logo.png"))
    #expect(decoded["tags"] == .array([.string("One"), .string("Two")]))
    #expect(decoded["items"]?.asArray?.first?.asRecord?["label"] == .string("One"))
    #expect(decoded["profile"]?.asRecord?["name"] == .string("Jordan"))
    #expect(decoded["when"]?.asDate == date)
}

@Test
func templateManifestSerializationMatchesRuntimeSchemaAndMetadata() throws {
    let manifest = TemplateManifest.make(
        for: DummyTemplate.self,
        bundleFile: "Dummy.bundle",
        previewFile: "preview.png"
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(manifest)
    let decoded = try JSONDecoder().decode(TemplateManifest.self, from: data)

    #expect(decoded.id == DummyTemplate.templateID)
    #expect(decoded.version == DummyTemplate.version)
    #expect(decoded.description == DummyTemplate.templateDescription)
    #expect(decoded.bundleFile == "Dummy.bundle")
    #expect(decoded.previewFile == "preview.png")
    #expect(decoded.metadata == DummyTemplate.metadata)
    #expect(decoded.schema == DummyTemplate.schema)
}

@Test
@MainActor
func rawTemplateStorePublishesExternalUpdates() async {
    let store = RawTemplateStore(
        values: ["name": .string("Acme")],
        persist: { _ in }
    )

    var cancellable: AnyCancellable?
    let stream = AsyncStream<Void> { continuation in
        cancellable = store.objectWillChange.sink {
            continuation.yield()
            continuation.finish()
        }
    }

    store.externalUpdate(["name": .string("Globex")])

    var iterator = stream.makeAsyncIterator()
    let event = await iterator.next()

    #expect(event != nil)
    #expect(store.values["name"] == .string("Globex"))
    withExtendedLifetime(cancellable) {}
}

// MARK: - HexColor Tests

@Test
func hexColorNormalizesWithoutHash() {
    let hex = HexColor("ff0000")
    #expect(hex.hex == "#ff0000")
}

@Test
func hexColorPreservesHash() {
    let hex = HexColor("#ff0000")
    #expect(hex.hex == "#ff0000")
}

@Test
func hexColorTrimsWhitespace() {
    let hex = HexColor(" #aabbcc ")
    #expect(hex.hex == "#aabbcc")
}

@Test
func hexColorInvalidReturnsFallback() {
    let hex = HexColor("xyz")
    #expect(hex.hex == "#xyz")
    // Invalid 3-char hex (not 6) falls back to .gray
    let color = hex.color
    #expect(color == Color.gray)
}

// MARK: - FieldValue Accessor Tests

@Test
func fieldValueAsStringReturnsForStringColorImage() {
    #expect(FieldValue.string("hello").asString == "hello")
    #expect(FieldValue.color("#ff0000").asString == "#ff0000")
    #expect(FieldValue.image("/tmp/logo.png").asString == "/tmp/logo.png")
}

@Test
func fieldValueAsNumberReturnsDouble() {
    #expect(FieldValue.number(3.14).asNumber == 3.14)
}

@Test
func fieldValueAccessorReturnsNilForMismatch() {
    #expect(FieldValue.string("x").asNumber == nil)
    #expect(FieldValue.number(1).asBool == nil)
    #expect(FieldValue.bool(true).asString == nil)
    #expect(FieldValue.string("x").asArray == nil)
    #expect(FieldValue.number(1).asRecord == nil)
    #expect(FieldValue.string("x").asDate == nil)
}

@Test
func fieldValueIsNull() {
    #expect(FieldValue.null.isNull == true)
    #expect(FieldValue.string("").isNull == false)
    #expect(FieldValue.number(0).isNull == false)
    #expect(FieldValue.bool(false).isNull == false)
}

// MARK: - FieldValue Literal Tests

@Test
func fieldValueStringLiteral() {
    let v: FieldValue = "hello"
    #expect(v == .string("hello"))
}

@Test
func fieldValueIntLiteral() {
    let v: FieldValue = 42
    #expect(v == .number(42))
}

@Test
func fieldValueBoolLiteral() {
    let v: FieldValue = true
    #expect(v == .bool(true))
}

// MARK: - Schema Helper Tests

@Test
func schemaFieldForKeyFindsField() {
    let schema = Schema(sections: [
        SchemaSection("Main", fields: [
            FieldDescriptor(key: "title", label: "Title", kind: .string, defaultValue: .string("Untitled")),
            FieldDescriptor(key: "count", label: "Count", kind: .number, defaultValue: .number(0)),
        ]),
    ])
    let field = schema.field(forKey: "title")
    #expect(field != nil)
    #expect(field?.kind == .string)
    #expect(field?.label == "Title")
}

@Test
func schemaFieldForKeyReturnsNilForUnknown() {
    let schema = Schema(sections: [
        SchemaSection("Main", fields: [
            FieldDescriptor(key: "title", label: "Title", kind: .string, defaultValue: .string("")),
        ]),
    ])
    #expect(schema.field(forKey: "bogus") == nil)
}

@Test
func schemaDefaultValuesPopulatesAllFields() {
    let schema = Schema(sections: [
        SchemaSection("A", fields: [
            FieldDescriptor(key: "name", label: "Name", kind: .string, defaultValue: .string("Default")),
        ]),
        SchemaSection("B", fields: [
            FieldDescriptor(key: "count", label: "Count", kind: .number, defaultValue: .number(10)),
        ]),
    ])
    let defaults = schema.defaultValues()
    #expect(defaults.count == 2)
    #expect(defaults["name"] == .string("Default"))
    #expect(defaults["count"] == .number(10))
}

// MARK: - JSONSchemaExport Tests

@Test
func jsonSchemaExportBasicTypes() {
    let stringProp = FieldDescriptor(key: "name", label: "Name", kind: .string, defaultValue: .string(""))
        .toJSONSchemaProperty()
    #expect(stringProp["type"] as? String == "string")

    let numberProp = FieldDescriptor(key: "count", label: "Count", kind: .number, defaultValue: .number(0))
        .toJSONSchemaProperty()
    #expect(numberProp["type"] as? String == "number")

    let boolProp = FieldDescriptor(key: "active", label: "Active", kind: .bool, defaultValue: .bool(false))
        .toJSONSchemaProperty()
    #expect(boolProp["type"] as? String == "boolean")
}

@Test
func jsonSchemaExportColorHasPattern() {
    let prop = FieldDescriptor(key: "accent", label: "Accent", kind: .color, defaultValue: .color("#000000"))
        .toJSONSchemaProperty()
    #expect(prop["type"] as? String == "string")
    #expect(prop["pattern"] as? String == "^#[0-9A-Fa-f]{6}$")
}

@Test
func jsonSchemaExportEnumHasEnumValues() {
    let prop = FieldDescriptor(
        key: "currency",
        label: "Currency",
        kind: .enumeration,
        defaultValue: .string("USD"),
        options: [
            EnumOption(value: "USD", label: "USD"),
            EnumOption(value: "EUR", label: "EUR"),
        ]
    ).toJSONSchemaProperty()
    #expect(prop["type"] as? String == "string")
    let enumValues = prop["enum"] as? [String]
    #expect(enumValues == ["USD", "EUR"])
}

@Test
func jsonSchemaExportConstraintsMap() {
    let prop = FieldDescriptor(
        key: "amount",
        label: "Amount",
        kind: .number,
        defaultValue: .number(0),
        constraints: [.min(0), .max(1000)]
    ).toJSONSchemaProperty()
    #expect(prop["minimum"] as? Double == 0)
    #expect(prop["maximum"] as? Double == 1000)

    let strProp = FieldDescriptor(
        key: "name",
        label: "Name",
        kind: .string,
        defaultValue: .string(""),
        constraints: [.maxLength(100)]
    ).toJSONSchemaProperty()
    #expect(strProp["maxLength"] as? Int == 100)
}

// MARK: - CurrencyUtils Tests

@Test
func currencySymbolKnownCodes() {
    #expect(currencySymbol(for: "EUR") == "\u{20AC}")
    #expect(currencySymbol(for: "GBP") == "\u{00A3}")
    #expect(currencySymbol(for: "JPY") == "\u{00A5}")
}

@Test
func currencySymbolDefaultDollar() {
    #expect(currencySymbol(for: "USD") == "$")
    #expect(currencySymbol(for: "XYZ") == "$")
    #expect(currencySymbol(for: "") == "$")
}
