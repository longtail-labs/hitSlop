-- Counter template: simple increment/decrement example

local template = {}

function template.schema()
    return {
        sections = {{
            title = "Counter",
            fields = {
                { key = "title", label = "Title", kind = "string", defaultValue = "My Counter" },
                { key = "count", label = "Count", kind = "number", defaultValue = 0 },
                { key = "step",  label = "Step",  kind = "number", defaultValue = 1 },
            }
        }}
    }
end

function template.metadata()
    return {
        width = 260, height = 320,
        windowShape = { type = "roundedRect", value = 20 },
        alwaysOnTop = true,
    }
end

function template.layout(data, theme, context)
    return Padding("all", 24, VStack(16, {
        Text(data.title, { font = "title2", weight = "bold", color = theme.foreground, alignment = "center" }),
        Spacer(),
        Text(tostring(math.floor(data.count)), {
            font = "largeTitle",
            weight = "bold",
            color = theme.accent,
            alignment = "center",
        }),
        Text("count", { font = "caption", color = theme.secondary, alignment = "center" }),
        Spacer(),
        HideInExport(HStack(12, {
            Button("-", "decrement", { style = "bordered" }),
            Button("+", "increment", { style = "bordered" }),
        })),
        HStack(4, {
            Text("Step:", { font = "caption", color = theme.secondary }),
            Text(tostring(math.floor(data.step)), { font = "caption", color = theme.foreground }),
        }),
    }))
end

function template.onAction(name, data)
    if name == "increment" then
        data.count = data.count + data.step
    elseif name == "decrement" then
        data.count = data.count - data.step
    end
    return data
end

return template
