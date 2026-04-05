import Testing
import Foundation
@testable import SlopIPC

// MARK: - AnyCodable Tests

@Test
func anyCodableStringRoundTrips() throws {
    let value = AnyCodable.string("hello")
    let data = try JSONEncoder().encode(value)
    let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
    #expect(decoded.stringValue == "hello")
}

@Test
func anyCodableIntRoundTrips() throws {
    let value = AnyCodable.int(42)
    let data = try JSONEncoder().encode(value)
    let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
    #expect(decoded.intValue == 42)
}

@Test
func anyCodableBoolRoundTrips() throws {
    let value = AnyCodable.bool(true)
    let data = try JSONEncoder().encode(value)
    let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
    #expect(decoded.boolValue == true)
}

@Test
func anyCodableDoubleRoundTrips() throws {
    let value = AnyCodable.double(3.14)
    let data = try JSONEncoder().encode(value)
    let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
    #expect(decoded.doubleValue == 3.14)
}

@Test
func anyCodableNullRoundTrips() throws {
    let value = AnyCodable.null
    let data = try JSONEncoder().encode(value)
    let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
    #expect(decoded.stringValue == nil)
    #expect(decoded.intValue == nil)
    #expect(decoded.boolValue == nil)
}

@Test
func anyCodableNestedObjectRoundTrips() throws {
    let value = AnyCodable.object(["k": .array([.int(1)])])
    let data = try JSONEncoder().encode(value)
    let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
    let inner = decoded.objectValue?["k"]?.arrayValue?.first
    #expect(inner?.intValue == 1)
}

@Test
func anyCodableAccessorsReturnNilForMismatch() {
    let str = AnyCodable.string("x")
    #expect(str.intValue == nil)
    #expect(str.boolValue == nil)
    #expect(str.doubleValue == nil)
    #expect(str.arrayValue == nil)
    #expect(str.objectValue == nil)

    let num = AnyCodable.int(5)
    #expect(num.stringValue == nil)
    #expect(num.boolValue == nil)
    #expect(num.arrayValue == nil)
}

@Test
func anyCodableIntFromWholeDouble() {
    let value = AnyCodable.double(5.0)
    #expect(value.intValue == 5)

    let fractional = AnyCodable.double(5.5)
    #expect(fractional.intValue == nil)
}

// MARK: - JSONRPCMessage Tests

@Test
func requestEncodesJsonrpc2() throws {
    let request = JSONRPCRequest(id: 1, method: "test")
    let data = try JSONEncoder().encode(request)
    let json = try JSONDecoder().decode([String: AnyCodable].self, from: data)
    #expect(json["jsonrpc"]?.stringValue == "2.0")
}

@Test
func requestRoundTripsWithParams() throws {
    let params = JSONRPCParams(["key": .string("value")])
    let request = JSONRPCRequest(id: 42, method: "test.method", params: params)
    let data = try JSONEncoder().encode(request)
    let decoded = try JSONDecoder().decode(JSONRPCRequest.self, from: data)
    #expect(decoded.id == 42)
    #expect(decoded.method == "test.method")
    #expect(decoded.params?.string("key") == "value")
}

@Test
func responseWithResultDecodes() throws {
    let result = JSONRPCParams(["status": .string("ok")])
    let response = JSONRPCResponse(id: 1, result: result)
    let data = try JSONEncoder().encode(response)
    let decoded = try JSONDecoder().decode(JSONRPCResponse.self, from: data)
    #expect(decoded.id == 1)
    #expect(decoded.result?.string("status") == "ok")
    #expect(decoded.error == nil)
}

@Test
func responseWithErrorDecodes() throws {
    let error = JSONRPCError.methodNotFound
    let response = JSONRPCResponse(id: 1, error: error)
    let data = try JSONEncoder().encode(response)
    let decoded = try JSONDecoder().decode(JSONRPCResponse.self, from: data)
    #expect(decoded.id == 1)
    #expect(decoded.error?.code == -32601)
    #expect(decoded.result == nil)
}

@Test
func errorStaticMethodCodes() {
    #expect(JSONRPCError.methodNotFound.code == -32601)
    #expect(JSONRPCError.invalidParams.code == -32602)
    #expect(JSONRPCError.internalError("test").code == -32603)
}

// MARK: - JSONRPCParams Tests

@Test
func paramsAccessorsWork() {
    let params = JSONRPCParams([
        "name": .string("hello"),
        "count": .int(42),
        "rate": .double(3.14),
        "active": .bool(true),
    ])
    #expect(params.string("name") == "hello")
    #expect(params.int("count") == 42)
    #expect(params.double("rate") == 3.14)
    #expect(params.bool("active") == true)
}

@Test
func paramsMissingKeyReturnsNil() {
    let params = JSONRPCParams(["existing": .string("value")])
    #expect(params.string("missing") == nil)
    #expect(params.int("missing") == nil)
    #expect(params.bool("missing") == nil)
}

@Test
func paramsEmptyIsEmpty() {
    #expect(JSONRPCParams.empty.values.isEmpty)
}

// MARK: - IPCTransport Tests

@Test
func encodeRequestAppendsNewline() throws {
    let request = JSONRPCRequest(id: 1, method: "test")
    let data = try IPCTransport.encode(request)
    #expect(data.last == 0x0A)
}

@Test
func encodeResponseAppendsNewline() throws {
    let response = JSONRPCResponse(id: 1, result: .empty)
    let data = try IPCTransport.encode(response)
    #expect(data.last == 0x0A)
}

@Test
func requestRoundTripThroughTransport() throws {
    let params = JSONRPCParams(["key": .string("value")])
    let request = JSONRPCRequest(id: 99, method: "roundtrip", params: params)
    let encoded = try IPCTransport.encode(request)
    let trimmed = encoded.dropLast()
    let decoded = try IPCTransport.decodeRequest(from: Data(trimmed))
    #expect(decoded.id == 99)
    #expect(decoded.method == "roundtrip")
    #expect(decoded.params?.string("key") == "value")
}

@Test
func responseRoundTripThroughTransport() throws {
    let result = JSONRPCParams(["answer": .int(42)])
    let response = JSONRPCResponse(id: 7, result: result)
    let encoded = try IPCTransport.encode(response)
    let trimmed = encoded.dropLast()
    let decoded = try IPCTransport.decodeResponse(from: Data(trimmed))
    #expect(decoded.id == 7)
    #expect(decoded.result?.int("answer") == 42)
}

// MARK: - SlopMethod Tests

@Test
func allCasesHas20Methods() {
    #expect(SlopMethod.allCases.count == 20)
}

@Test
func rawValuesMatchExpected() {
    #expect(SlopMethod.templateList.rawValue == "template.list")
    #expect(SlopMethod.documentCreate.rawValue == "document.create")
    #expect(SlopMethod.status.rawValue == "status")
    #expect(SlopMethod.pickerShow.rawValue == "picker.show")
    #expect(SlopMethod.recentsClear.rawValue == "recents.clear")
}

@Test
func initFromInvalidRawValueReturnsNil() {
    #expect(SlopMethod(rawValue: "bogus.method") == nil)
    #expect(SlopMethod(rawValue: "") == nil)
}

// MARK: - Request/Response Builder Tests

@Test
func templateSchemaRequestContainsTemplateID() {
    let params = SlopRequest.templateSchema(templateID: "com.test.template")
    #expect(params.string("templateID") == "com.test.template")
}

@Test
func documentCreateRequestBuildsAllParams() {
    let params = SlopRequest.documentCreate(
        templateID: "com.test",
        outputPath: "/tmp/test.slop",
        data: "{\"title\":\"Hello\"}",
        theme: "ocean",
        open: true
    )
    #expect(params.string("templateID") == "com.test")
    #expect(params.string("outputPath") == "/tmp/test.slop")
    #expect(params.string("data") == "{\"title\":\"Hello\"}")
    #expect(params.string("theme") == "ocean")
    #expect(params.bool("open") == true)
}

@Test
func statusResponseHasExpectedKeys() {
    let response = SlopResponse.status(running: true, pid: 12345, version: "1.0.0")
    #expect(response.bool("running") == true)
    #expect(response.int("pid") == 12345)
    #expect(response.string("version") == "1.0.0")
}

@Test
func validateResponseHasExpectedKeys() {
    let response = SlopResponse.validate(valid: false, errors: ["Missing field: title"])
    #expect(response.bool("valid") == false)
    let errors = response.values["errors"]?.arrayValue
    #expect(errors?.count == 1)
    #expect(errors?.first?.stringValue == "Missing field: title")
}
