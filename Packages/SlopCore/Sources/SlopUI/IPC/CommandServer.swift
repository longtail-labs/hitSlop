import Foundation
import SlopIPC

/// Unix domain socket server that accepts JSON-RPC 2.0 requests from the CLI.
@MainActor
public final class CommandServer {
    private let socketPath: String
    private var serverFD: Int32 = -1
    private var acceptSource: DispatchSourceRead?
    public var handler: ((JSONRPCRequest) async -> JSONRPCResponse)?

    public init(socketPath: String = IPCTransport.socketPath) {
        self.socketPath = socketPath
    }

    public func start() throws {
        // Clean up stale socket
        unlink(socketPath)

        // Ensure directory exists
        let dir = (socketPath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        // Create socket
        serverFD = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverFD >= 0 else {
            throw ServerError.socketCreationFailed
        }

        // Bind
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = socketPath.utf8CString
        guard pathBytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else {
            Darwin.close(serverFD)
            throw ServerError.pathTooLong
        }
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: pathBytes.count) { dest in
                for (i, byte) in pathBytes.enumerated() {
                    dest[i] = byte
                }
            }
        }

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                bind(serverFD, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0 else {
            Darwin.close(serverFD)
            throw ServerError.bindFailed(String(cString: strerror(errno)))
        }

        // Listen
        guard listen(serverFD, 5) == 0 else {
            Darwin.close(serverFD)
            throw ServerError.listenFailed
        }

        // Write PID file
        let pidPath = IPCTransport.pidPath
        try "\(ProcessInfo.processInfo.processIdentifier)".write(
            toFile: pidPath, atomically: true, encoding: .utf8
        )

        // Accept connections via dispatch source
        let source = DispatchSource.makeReadSource(fileDescriptor: serverFD, queue: .main)
        source.setEventHandler { [weak self] in
            self?.acceptConnection()
        }
        source.setCancelHandler { [serverFD = self.serverFD] in
            Darwin.close(serverFD)
        }
        source.resume()
        acceptSource = source

        NSLog("CommandServer: listening on \(socketPath)")
    }

    public func stop() {
        acceptSource?.cancel()
        acceptSource = nil
        unlink(socketPath)
        unlink(IPCTransport.pidPath)
        serverFD = -1
    }

    private func acceptConnection() {
        let clientFD = accept(serverFD, nil, nil)
        guard clientFD >= 0 else { return }

        // Handle on a background queue, dispatch handler call to main
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.handleClient(clientFD)
        }
    }

    private nonisolated func handleClient(_ fd: Int32) {
        defer { Darwin.close(fd) }

        // Read until newline
        var buffer = Data()
        let chunkSize = 65536
        let chunk = UnsafeMutablePointer<UInt8>.allocate(capacity: chunkSize)
        defer { chunk.deallocate() }

        while true {
            let bytesRead = recv(fd, chunk, chunkSize, 0)
            if bytesRead <= 0 { return }
            buffer.append(chunk, count: bytesRead)
            if buffer.last == 0x0A { break }
        }

        if buffer.last == 0x0A { buffer.removeLast() }

        guard let request = try? IPCTransport.decodeRequest(from: buffer) else {
            // Send parse error
            let errorResponse = JSONRPCResponse(
                id: 0,
                error: JSONRPCError(code: -32700, message: "Parse error")
            )
            if let data = try? IPCTransport.encode(errorResponse) {
                _ = data.withUnsafeBytes { buf in
                    Darwin.send(fd, buf.baseAddress!, buf.count, 0)
                }
            }
            return
        }

        // Dispatch to handler on main actor.
        // The semaphore serializes access so there is no data race.
        let semaphore = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var response: JSONRPCResponse?

        DispatchQueue.main.async { [weak self] in
            guard let self else {
                response = JSONRPCResponse(
                    id: request.id,
                    error: .internalError("Server shutting down")
                )
                semaphore.signal()
                return
            }

            Task { @MainActor in
                if let handler = self.handler {
                    response = await handler(request)
                } else {
                    response = JSONRPCResponse(
                        id: request.id,
                        error: .internalError("No handler registered")
                    )
                }
                semaphore.signal()
            }
        }

        semaphore.wait()

        guard let resp = response, let data = try? IPCTransport.encode(resp) else { return }
        _ = data.withUnsafeBytes { buf in
            Darwin.send(fd, buf.baseAddress!, buf.count, 0)
        }
    }

    public enum ServerError: LocalizedError {
        case socketCreationFailed
        case pathTooLong
        case bindFailed(String)
        case listenFailed

        public var errorDescription: String? {
            switch self {
            case .socketCreationFailed: "Failed to create socket"
            case .pathTooLong: "Socket path too long"
            case .bindFailed(let msg): "Failed to bind socket: \(msg)"
            case .listenFailed: "Failed to listen on socket"
            }
        }
    }
}
