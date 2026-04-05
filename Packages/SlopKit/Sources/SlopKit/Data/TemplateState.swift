import SwiftUI

/// Property wrapper for template views to access their typed data model.
/// Bridges between RawTemplateStore (host-side [String: FieldValue]) and
/// the typed @Template struct (template-side).
///
/// Usage in a template view:
/// ```swift
/// struct InvoiceView: View {
///     @TemplateState var data: InvoiceData
///     var body: some View {
///         Text(data.companyName)
///         TextField("Name", text: $data.companyName)
///     }
/// }
/// ```
@MainActor
@propertyWrapper
public struct TemplateState<Data: TemplateDataProtocol>: DynamicProperty {
    @ObservedObject private var store: RawTemplateStore

    public init(store: RawTemplateStore) {
        self._store = ObservedObject(wrappedValue: store)
    }

    public var wrappedValue: Data {
        get { Data(from: store.values) }
        nonmutating set {
            store.setValues(newValue.toFieldValues())
        }
    }

    public var projectedValue: Binding<Data> {
        let store = self.store
        return Binding(
            get: { Data(from: store.values) },
            set: { newValue in
                store.setValues(newValue.toFieldValues())
            }
        )
    }
}

/// Alias for `TemplateState` — preferred name when used with `@SlopTemplate` macro.
public typealias TemplateData = TemplateState
