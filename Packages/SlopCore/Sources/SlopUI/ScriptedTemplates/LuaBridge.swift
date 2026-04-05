import Foundation
import SlopKit
import Lua

// MARK: - FieldValue ↔ Lua Conversion

/// Push a FieldValue onto the Lua stack.
func pushFieldValue(_ L: LuaState, _ value: FieldValue) {
    switch value {
    case .string(let v):
        L.push(utf8String: v)
    case .number(let v):
        L.push(v)
    case .bool(let v):
        L.push(v)
    case .color(let v):
        L.push(utf8String: v)
    case .date(let v):
        L.push(v.timeIntervalSince1970)
    case .image(let v):
        L.push(utf8String: v)
    case .array(let items):
        L.newtable(narr: CInt(items.count))
        for (i, item) in items.enumerated() {
            pushFieldValue(L, item)
            L.rawset(-2, key: lua_Integer(i + 1))
        }
    case .record(let dict):
        L.newtable(nrec: CInt(dict.count))
        for (key, val) in dict {
            pushFieldValue(L, val)
            L.rawset(-2, utf8Key: key)
        }
    case .null:
        L.pushnil()
    }
}

/// Read a Lua value at the given stack index and convert to FieldValue.
func toFieldValue(_ L: LuaState, at index: CInt) -> FieldValue {
    let absIndex = index > 0 ? index : L.gettop() + index + 1
    switch L.type(absIndex) {
    case .nil:
        return .null
    case .boolean:
        return .bool(L.toboolean(absIndex))
    case .number:
        return .number(L.tonumber(absIndex) ?? 0)
    case .string:
        return .string(L.tostring(absIndex) ?? "")
    case .table:
        if isLuaArray(L, at: absIndex) {
            var items: [FieldValue] = []
            // for_ipairs: closure gets (index), value is on stack top
            try? L.for_ipairs(absIndex) { (_: lua_Integer) -> Void in
                items.append(toFieldValue(L, at: -1))
            }
            return .array(items)
        } else {
            var dict: [String: FieldValue] = [:]
            // for_pairs: closure gets (keyIdx, valIdx)
            try? L.for_pairs(absIndex) { (k: CInt, v: CInt) -> Void in
                if let key = L.tostring(k) {
                    dict[key] = toFieldValue(L, at: v)
                }
            }
            return .record(dict)
        }
    default:
        return .null
    }
}

/// Heuristic: a Lua table is an "array" if it has a positive length and key 1 exists.
private func isLuaArray(_ L: LuaState, at index: CInt) -> Bool {
    let len = L.rawlen(index)
    if len == 0 {
        var hasStringKey = false
        try? L.for_pairs(index) { (k: CInt, _: CInt) -> Void in
            if L.type(k) == .string {
                hasStringKey = true
            }
        }
        return !hasStringKey
    }
    return true
}

// MARK: - Extract Children from Lua Table

func extractChildren(_ L: LuaState, at index: CInt) -> [LayoutNode] {
    var children: [LayoutNode] = []
    let absIndex = index > 0 ? index : L.gettop() + index + 1

    guard L.type(absIndex) == .table else { return children }

    try? L.for_ipairs(absIndex) { (_: lua_Integer) -> Void in
        if let node: LayoutNode = L.touserdata(-1) {
            children.append(node)
        }
    }
    return children
}

// MARK: - Extract TextStyle from Lua Table

func extractTextStyle(_ L: LuaState, at index: CInt) -> TextStyle {
    guard L.type(index) == .table else { return TextStyle() }

    var style = TextStyle()

    if L.rawget(index, utf8Key: "font") == .string {
        style.font = TextStyle.FontStyle(rawValue: L.tostring(-1) ?? "body")
    }
    L.pop()

    if L.rawget(index, utf8Key: "weight") == .string {
        style.weight = TextStyle.FontWeight(rawValue: L.tostring(-1) ?? "regular")
    }
    L.pop()

    if L.rawget(index, utf8Key: "color") == .string {
        style.color = L.tostring(-1)
    }
    L.pop()

    if L.rawget(index, utf8Key: "alignment") == .string {
        style.alignment = TextStyle.TextAlignment(rawValue: L.tostring(-1) ?? "leading")
    }
    L.pop()

    if L.rawget(index, utf8Key: "lineLimit") == .number {
        style.lineLimit = L.tointeger(-1).map(Int.init)
    }
    L.pop()

    return style
}

// MARK: - LayoutNode Metatable

func registerLayoutNodeMetatable(_ L: LuaState) {
    L.register(Metatable<LayoutNode>(
        tostring: .closure { L in
            L.push(utf8String: "LayoutNode")
            return 1
        }
    ))
}

// MARK: - Register All Layout Constructors

func registerLayoutConstructors(_ L: LuaState) {

    // VStack(spacing, { children })
    L.push({ (L: LuaState) -> CInt in
        let spacing = L.tonumber(1) ?? 0
        let children = extractChildren(L, at: 2)
        L.push(userdata: LayoutNode.vstack(spacing: CGFloat(spacing), children: children))
        return 1
    })
    L.setglobal(name: "VStack")

    // HStack(spacing, { children })
    L.push({ (L: LuaState) -> CInt in
        let spacing = L.tonumber(1) ?? 0
        let children = extractChildren(L, at: 2)
        L.push(userdata: LayoutNode.hstack(spacing: CGFloat(spacing), children: children))
        return 1
    })
    L.setglobal(name: "HStack")

    // ZStack({ children })
    L.push({ (L: LuaState) -> CInt in
        let children = extractChildren(L, at: 1)
        L.push(userdata: LayoutNode.zstack(children: children))
        return 1
    })
    L.setglobal(name: "ZStack")

    // Text(content, { style })
    L.push({ (L: LuaState) -> CInt in
        let content = L.tostring(1) ?? ""
        let style = extractTextStyle(L, at: 2)
        L.push(userdata: LayoutNode.text(content, style))
        return 1
    })
    L.setglobal(name: "Text")

    // Divider()
    L.push({ (L: LuaState) -> CInt in
        L.push(userdata: LayoutNode.divider)
        return 1
    })
    L.setglobal(name: "Divider")

    // Spacer(minLength?)
    L.push({ (L: LuaState) -> CInt in
        let minLength = L.tonumber(1).map { CGFloat($0) }
        L.push(userdata: LayoutNode.spacer(minLength: minLength))
        return 1
    })
    L.setglobal(name: "Spacer")

    // Button(label, action, { style? })
    L.push({ (L: LuaState) -> CInt in
        let label = L.tostring(1) ?? ""
        let action = L.tostring(2) ?? ""
        var variant: LayoutNode.ButtonVariant?
        if L.type(3) == .table {
            if L.rawget(3, utf8Key: "style") == .string {
                variant = LayoutNode.ButtonVariant(rawValue: L.tostring(-1) ?? "")
            }
            L.pop()
        }
        L.push(userdata: LayoutNode.button(label: label, action: action, style: variant))
        return 1
    })
    L.setglobal(name: "Button")

    // Image(systemName, { size?, color? })
    L.push({ (L: LuaState) -> CInt in
        let systemName = L.tostring(1) ?? ""
        var size: CGFloat?
        var color: String?
        if L.type(2) == .table {
            if L.rawget(2, utf8Key: "size") == .number {
                size = L.tonumber(-1).map { CGFloat($0) }
            }
            L.pop()
            if L.rawget(2, utf8Key: "color") == .string {
                color = L.tostring(-1)
            }
            L.pop()
        }
        L.push(userdata: LayoutNode.image(systemName: systemName, size: size, color: color))
        return 1
    })
    L.setglobal(name: "Image")

    // ProgressBar(value, total, { color? })
    L.push({ (L: LuaState) -> CInt in
        let value = L.tonumber(1) ?? 0
        let total = L.tonumber(2) ?? 1
        var color: String?
        if L.type(3) == .table {
            if L.rawget(3, utf8Key: "color") == .string {
                color = L.tostring(-1)
            }
            L.pop()
        }
        L.push(userdata: LayoutNode.progressBar(value: value, total: total, color: color))
        return 1
    })
    L.setglobal(name: "ProgressBar")

    // ColorDot(hex, size)
    L.push({ (L: LuaState) -> CInt in
        let hex = L.tostring(1) ?? "#808080"
        let size = L.tonumber(2) ?? 10
        L.push(userdata: LayoutNode.colorDot(hex: hex, size: CGFloat(size)))
        return 1
    })
    L.setglobal(name: "ColorDot")

    // Toggle(fieldKey, label)
    L.push({ (L: LuaState) -> CInt in
        let fieldKey = L.tostring(1) ?? ""
        let label = L.tostring(2) ?? ""
        L.push(userdata: LayoutNode.toggle(fieldKey: fieldKey, label: label))
        return 1
    })
    L.setglobal(name: "Toggle")

    // TextField(fieldKey, placeholder)
    L.push({ (L: LuaState) -> CInt in
        let fieldKey = L.tostring(1) ?? ""
        let placeholder = L.tostring(2) ?? ""
        L.push(userdata: LayoutNode.textField(fieldKey: fieldKey, placeholder: placeholder))
        return 1
    })
    L.setglobal(name: "TextField")

    // NumberField(fieldKey)
    L.push({ (L: LuaState) -> CInt in
        let fieldKey = L.tostring(1) ?? ""
        L.push(userdata: LayoutNode.numberField(fieldKey: fieldKey))
        return 1
    })
    L.setglobal(name: "NumberField")

    // Picker(fieldKey, { options })
    L.push({ (L: LuaState) -> CInt in
        let fieldKey = L.tostring(1) ?? ""
        var options: [(value: String, label: String)] = []
        if L.type(2) == .table {
            try? L.for_ipairs(2) { (_: lua_Integer) -> Void in
                // Value (the option table) is on top of stack
                let optIdx = L.gettop()
                if L.type(optIdx) == .table {
                    var value = ""
                    var label = ""
                    if L.rawget(optIdx, utf8Key: "value") == .string {
                        value = L.tostring(-1) ?? ""
                    }
                    L.pop()
                    if L.rawget(optIdx, utf8Key: "label") == .string {
                        label = L.tostring(-1) ?? ""
                    }
                    L.pop()
                    options.append((value: value, label: label))
                }
            }
        }
        L.push(userdata: LayoutNode.picker(fieldKey: fieldKey, options: options))
        return 1
    })
    L.setglobal(name: "Picker")

    // Slider(fieldKey, min, max, step?)
    L.push({ (L: LuaState) -> CInt in
        let fieldKey = L.tostring(1) ?? ""
        let rangeMin = L.tonumber(2) ?? 0
        let rangeMax = L.tonumber(3) ?? 100
        let step = L.tonumber(4)
        L.push(userdata: LayoutNode.slider(
            fieldKey: fieldKey,
            range: rangeMin...rangeMax,
            step: step
        ))
        return 1
    })
    L.setglobal(name: "Slider")

    // ScrollView(child) or ScrollView(axes, child)
    L.push({ (L: LuaState) -> CInt in
        let child: LayoutNode
        var axes: LayoutNode.ScrollAxes = .vertical
        if L.type(1) == .string {
            let axesStr = L.tostring(1) ?? "vertical"
            switch axesStr {
            case "horizontal": axes = .horizontal
            case "both": axes = .both
            default: axes = .vertical
            }
            child = L.touserdata(2) ?? .empty
        } else {
            child = L.touserdata(1) ?? .empty
        }
        L.push(userdata: LayoutNode.scrollView(axes: axes, child: child))
        return 1
    })
    L.setglobal(name: "ScrollView")

    // Padding(edges, amount, child) or Padding(amount, child)
    L.push({ (L: LuaState) -> CInt in
        let edges: LayoutNode.EdgeSet
        let amount: CGFloat
        let child: LayoutNode
        if L.type(1) == .string {
            edges = parseEdgeSet(L.tostring(1) ?? "all")
            amount = CGFloat(L.tonumber(2) ?? 0)
            child = L.touserdata(3) ?? .empty
        } else {
            edges = .all
            amount = CGFloat(L.tonumber(1) ?? 0)
            child = L.touserdata(2) ?? .empty
        }
        L.push(userdata: LayoutNode.padding(edges, amount, child: child))
        return 1
    })
    L.setglobal(name: "Padding")

    // Frame({ width?, height?, alignment? }, child)
    L.push({ (L: LuaState) -> CInt in
        var width: CGFloat?
        var height: CGFloat?
        var alignment: LayoutNode.FrameAlignment?
        if L.type(1) == .table {
            if L.rawget(1, utf8Key: "width") == .number {
                width = L.tonumber(-1).map { CGFloat($0) }
            }
            L.pop()
            if L.rawget(1, utf8Key: "height") == .number {
                height = L.tonumber(-1).map { CGFloat($0) }
            }
            L.pop()
            if L.rawget(1, utf8Key: "alignment") == .string {
                alignment = LayoutNode.FrameAlignment(rawValue: L.tostring(-1) ?? "")
            }
            L.pop()
        }
        let child: LayoutNode = L.touserdata(2) ?? .empty
        L.push(userdata: LayoutNode.frame(width: width, height: height, alignment: alignment, child: child))
        return 1
    })
    L.setglobal(name: "Frame")

    // Background(color, cornerRadius, child)
    L.push({ (L: LuaState) -> CInt in
        let color = L.tostring(1) ?? "#000000"
        let cornerRadius = CGFloat(L.tonumber(2) ?? 0)
        let child: LayoutNode = L.touserdata(3) ?? .empty
        L.push(userdata: LayoutNode.background(color: color, cornerRadius: cornerRadius, child: child))
        return 1
    })
    L.setglobal(name: "Background")

    // HideInExport(child)
    L.push({ (L: LuaState) -> CInt in
        let child: LayoutNode = L.touserdata(1) ?? .empty
        L.push(userdata: LayoutNode.exportVisibility(.hideInExport, child: child))
        return 1
    })
    L.setglobal(name: "HideInExport")

    // OnlyInExport(child)
    L.push({ (L: LuaState) -> CInt in
        let child: LayoutNode = L.touserdata(1) ?? .empty
        L.push(userdata: LayoutNode.exportVisibility(.onlyInExport, child: child))
        return 1
    })
    L.setglobal(name: "OnlyInExport")

    // ForEach(arrayFieldKey, builderFunction)
    // Note: ForEach captures the Lua builder function and calls it during layout.
    // The builder receives (item_table, 1-based_index) and must return a LayoutNode.
    L.push({ (L: LuaState) -> CInt in
        let arrayKey = L.tostring(1) ?? ""
        // Capture the Lua function reference
        nonisolated(unsafe) let builderRef = L.ref(index: 2)
        nonisolated(unsafe) let luaState = L

        let node = LayoutNode.forEach(arrayFieldKey: arrayKey) { record, index in
            pushFieldValue(luaState, .record(record))
            luaState.push(lua_Integer(index + 1))
            do {
                builderRef.push(onto: luaState)
                luaState.push(index: -3) // push record (arg 1)
                luaState.push(index: -3) // push index (arg 2)
                try luaState.pcall(nargs: 2, nret: 1)
                let result: LayoutNode = luaState.touserdata(-1) ?? .empty
                luaState.pop(3) // pop result + record + index
                return result
            } catch {
                luaState.pop(2) // pop record + index
                return .text("ForEach error: \(error)", TextStyle(color: "#ff0000"))
            }
        }
        L.push(userdata: node)
        return 1
    })
    L.setglobal(name: "ForEach")

    // If(condition, thenNode, elseNode?)
    L.push({ (L: LuaState) -> CInt in
        let condition = L.toboolean(1)
        let thenNode: LayoutNode = L.touserdata(2) ?? .empty
        let elseNode: LayoutNode? = L.touserdata(3)
        L.push(userdata: LayoutNode.conditional(predicate: condition, then: thenNode, otherwise: elseNode))
        return 1
    })
    L.setglobal(name: "If")
}

// MARK: - Edge Parsing

private func parseEdgeSet(_ str: String) -> LayoutNode.EdgeSet {
    switch str {
    case "horizontal": return .horizontal
    case "vertical": return .vertical
    case "top": return .top
    case "bottom": return .bottom
    case "leading": return .leading
    case "trailing": return .trailing
    default: return .all
    }
}

// MARK: - Schema Parsing

func parseSchema(_ L: LuaState, at index: CInt) -> Schema {
    let absIndex = index > 0 ? index : L.gettop() + index + 1
    guard L.type(absIndex) == .table else { return Schema(sections: []) }

    var sections: [SchemaSection] = []

    if L.rawget(absIndex, utf8Key: "sections") == .table {
        let sectionsIdx = L.gettop()
        try? L.for_ipairs(sectionsIdx) { (_: lua_Integer) -> Void in
            // Section table is on top of stack
            let sectionIdx = L.gettop()
            var title = ""
            if L.rawget(sectionIdx, utf8Key: "title") == .string {
                title = L.tostring(-1) ?? ""
            }
            L.pop()

            var fields: [FieldDescriptor] = []
            if L.rawget(sectionIdx, utf8Key: "fields") == .table {
                let fieldsIdx = L.gettop()
                try L.for_ipairs(fieldsIdx) { (_: lua_Integer) -> Void in
                    if let field = parseFieldDescriptor(L, at: L.gettop()) {
                        fields.append(field)
                    }
                }
            }
            L.pop()

            sections.append(SchemaSection(title, fields: fields))
        }
    }
    L.pop()

    return Schema(sections: sections)
}

func parseFieldDescriptor(_ L: LuaState, at index: CInt) -> FieldDescriptor? {
    guard L.type(index) == .table else { return nil }

    var key = ""
    var label = ""
    var kindStr = "string"
    var defaultValue: FieldValue = .null

    if L.rawget(index, utf8Key: "key") == .string { key = L.tostring(-1) ?? "" }
    L.pop()
    if L.rawget(index, utf8Key: "label") == .string { label = L.tostring(-1) ?? "" }
    L.pop()
    if L.rawget(index, utf8Key: "kind") == .string { kindStr = L.tostring(-1) ?? "string" }
    L.pop()

    let kind = FieldKind(rawValue: kindStr) ?? .string

    if L.rawget(index, utf8Key: "defaultValue") != .nil {
        defaultValue = toFieldValue(L, at: -1)
        switch kind {
        case .color:
            if let s = defaultValue.asString { defaultValue = .color(s) }
        case .image:
            if let s = defaultValue.asString { defaultValue = .image(s) }
        default:
            break
        }
    }
    L.pop()

    var options: [EnumOption]?
    if L.rawget(index, utf8Key: "options") == .table {
        let optIdx = L.gettop()
        var opts: [EnumOption] = []
        try? L.for_ipairs(optIdx) { (_: lua_Integer) -> Void in
            let oIdx = L.gettop()
            var value = ""
            var optLabel = ""
            if L.rawget(oIdx, utf8Key: "value") == .string { value = L.tostring(-1) ?? "" }
            L.pop()
            if L.rawget(oIdx, utf8Key: "label") == .string { optLabel = L.tostring(-1) ?? "" }
            L.pop()
            opts.append(EnumOption(value: value, label: optLabel))
        }
        options = opts
    }
    L.pop()

    var itemSchema: Schema?
    if L.rawget(index, utf8Key: "itemSchema") == .table {
        let isIdx = L.gettop()
        if L.rawget(isIdx, utf8Key: "fields") == .table {
            let fieldsIdx = L.gettop()
            var fields: [FieldDescriptor] = []
            try? L.for_ipairs(fieldsIdx) { (_: lua_Integer) -> Void in
                if let f = parseFieldDescriptor(L, at: L.gettop()) {
                    fields.append(f)
                }
            }
            itemSchema = Schema(sections: [SchemaSection("", fields: fields)])
        }
        L.pop()
    }
    L.pop()

    return FieldDescriptor(
        key: key,
        label: label,
        kind: kind,
        defaultValue: defaultValue,
        options: options,
        itemSchema: itemSchema
    )
}

// MARK: - Metadata Parsing

func parseMetadata(_ L: LuaState, at index: CInt) -> TemplateMetadata {
    let absIndex = index > 0 ? index : L.gettop() + index + 1
    guard L.type(absIndex) == .table else {
        return TemplateMetadata()
    }

    var width: CGFloat = 400
    var height: CGFloat = 600
    var windowShape: WindowShape = .roundedRect(radius: 16)
    var theme: String?
    var alwaysOnTop = true
    var category: String?

    if L.rawget(absIndex, utf8Key: "width") == .number {
        width = CGFloat(L.tonumber(-1) ?? 400)
    }
    L.pop()

    if L.rawget(absIndex, utf8Key: "height") == .number {
        height = CGFloat(L.tonumber(-1) ?? 600)
    }
    L.pop()

    if L.rawget(absIndex, utf8Key: "theme") == .string {
        theme = L.tostring(-1)
    }
    L.pop()

    if L.rawget(absIndex, utf8Key: "alwaysOnTop") == .boolean {
        alwaysOnTop = L.toboolean(-1)
    }
    L.pop()

    if L.rawget(absIndex, utf8Key: "category") == .string {
        category = L.tostring(-1)
    }
    L.pop()

    if L.rawget(absIndex, utf8Key: "windowShape") == .table {
        let wsIdx = L.gettop()
        if L.rawget(wsIdx, utf8Key: "type") == .string {
            let shapeType = L.tostring(-1) ?? ""
            L.pop()
            switch shapeType {
            case "roundedRect":
                if L.rawget(wsIdx, utf8Key: "value") == .number {
                    windowShape = .roundedRect(radius: CGFloat(L.tonumber(-1) ?? 16))
                }
                L.pop()
            case "circle":
                windowShape = .circle
            case "capsule":
                windowShape = .capsule
            case "path":
                if L.rawget(wsIdx, utf8Key: "value") == .string {
                    windowShape = .path(L.tostring(-1) ?? "")
                }
                L.pop()
            case "skin":
                if L.rawget(wsIdx, utf8Key: "value") == .string {
                    windowShape = .skin(L.tostring(-1) ?? "")
                }
                L.pop()
            default:
                break
            }
        } else {
            L.pop()
        }
    }
    L.pop()

    return TemplateMetadata(
        width: width,
        height: height,
        windowShape: windowShape,
        theme: theme,
        alwaysOnTop: alwaysOnTop,
        categories: category.map { [$0] } ?? []
    )
}
