import Foundation

/// Unix domain socket client for CLI → app communication.
public final class SocketClient: Sendable {
    private let socketPath: String

    public init(socketPath: String = IPCTransport.socketPath) {
        self.socketPath = socketPath
    }

    /// Send a request and wait for a response.
    public func send(_ request: JSONRPCRequest, timeout: TimeInterval = 30) throws -> JSONRPCResponse {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw SocketError.connectionFailed("Failed to create socket")
        }
        defer { close(fd) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = socketPath.utf8CString
        guard pathBytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else {
            throw SocketError.connectionFailed("Socket path too long")
        }
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: pathBytes.count) { dest in
                for (i, byte) in pathBytes.enumerated() {
                    dest[i] = byte
                }
            }
        }

        // Set connect timeout
        var tv = timeval(tv_sec: 5, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        let connectResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                Darwin.connect(fd, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connectResult == 0 else {
            throw SocketError.connectionFailed(
                "Cannot connect to hitSlop app. Is it running? (socket: \(socketPath))"
            )
        }

        // Send request
        let requestData = try IPCTransport.encode(request)
        let sent = requestData.withUnsafeBytes { buf in
            Darwin.send(fd, buf.baseAddress!, buf.count, 0)
        }
        guard sent == requestData.count else {
            throw SocketError.sendFailed("Failed to send request")
        }

        // Set read timeout
        var readTV = timeval(tv_sec: Int(timeout), tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &readTV, socklen_t(MemoryLayout<timeval>.size))

        // Read response (newline-delimited)
        var buffer = Data()
        let chunkSize = 65536
        let chunk = UnsafeMutablePointer<UInt8>.allocate(capacity: chunkSize)
        defer { chunk.deallocate() }

        while true {
            let bytesRead = recv(fd, chunk, chunkSize, 0)
            if bytesRead <= 0 {
                if bytesRead == 0 { break }
                throw SocketError.readFailed("Failed to read response")
            }
            buffer.append(chunk, count: bytesRead)
            if buffer.last == 0x0A { break } // newline terminates message
        }

        // Trim trailing newline
        if buffer.last == 0x0A {
            buffer.removeLast()
        }

        return try IPCTransport.decodeResponse(from: buffer)
    }

    /// Check if the app socket exists.
    public var isAppRunning: Bool {
        FileManager.default.fileExists(atPath: socketPath)
    }

    public enum SocketError: LocalizedError {
        case connectionFailed(String)
        case sendFailed(String)
        case readFailed(String)

        public var errorDescription: String? {
            switch self {
            case .connectionFailed(let msg): msg
            case .sendFailed(let msg): msg
            case .readFailed(let msg): msg
            }
        }
    }
}
