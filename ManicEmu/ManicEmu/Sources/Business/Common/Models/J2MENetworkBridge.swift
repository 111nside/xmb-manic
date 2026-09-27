//
//  J2MENetworkBridge.swift
//  ManicEmu
//
//  Network bridge for J2ME J2meJS core - handles HTTP requests and TCP sockets
//  via evalNative commands from JavaScript.
//

import Foundation
import Network
import WebKit

/// Callback type for HTTP requests and socket events
typealias J2MENetworkCallback = ([String: Any]) -> Void

/// Pending connection request
private struct PendingConnection {
    let data: [String: Any]
    let callback: J2MENetworkCallback?
    let timestamp: Date
}

/// Handles all network operations for J2meJS core
final class J2MENetworkBridge {

    // MARK: - Socket State

    /// Active socket connections: socketId -> NWConnection
    private var sockets: [String: NWConnection] = [:]

    /// Host tracking: host -> [socketIds] for per-host connection limiting
    private var hostSockets: [String: [String]] = [:]

    /// Socket event callbacks: socketId -> callback
    private var socketCallbacks: [String: J2MENetworkCallback] = [:]

    /// Next socket ID counter
    private var nextSocketId: Int = 1

    /// Weak reference back to J2MEView for evaluateJavaScript
    private weak var webView: WKWebView?

    /// Queue for socket operations
    private let socketQueue = DispatchQueue(label: "com.manicemu.j2me.network.socket")

    /// Pending connection requests (queued to avoid server overload)
    private var pendingConnections: [PendingConnection] = []

    /// Maximum concurrent connections per host
    private let maxConnectionsPerHost = 2

    /// Connection timeout for pending requests (seconds)
    private let pendingConnectionTimeout: TimeInterval = 10.0

    // MARK: - Initialization

    init(webView: WKWebView) {
        self.webView = webView
    }

    // MARK: - Public API

    /// Handle evalNative command from JavaScript
    /// - Parameters:
    ///   - command: The command name ("request", "connectSocket", "onSocket", "invokeSocket")
    ///   - data: Command parameters dictionary
    ///   - callback: Optional callback for async responses (used by socket commands)
    func handleCommand(_ command: String, data: [String: Any], callback: J2MENetworkCallback?) {
        switch command {
        case "request":
            handleHTTPRequest(data)
        case "connectSocket":
            handleConnectSocket(data, callback: callback)
        case "onSocket":
            handleOnSocket(data, callback: callback)
        case "invokeSocket":
            handleInvokeSocket(data)
        default:
            Log.debug("J2MENetworkBridge: unknown command \(command)")
        }
    }

    // MARK: - HTTP Request

    private func handleHTTPRequest(_ data: [String: Any]) {
        guard let urlString = data["url"] as? String,
              let url = URL(string: urlString) else {
            Log.debug("J2MENetworkBridge: invalid URL")
            return
        }

        let method = data["method"] as? String ?? "GET"
        let headers = data["headers"] as? [String: String] ?? [:]
        let responseType = data["responseType"] as? String ?? "utf8"

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.allHTTPHeaderFields = headers

        // Handle request body (base64 encoded)
        if let bodyData = data["data"] as? String,
           let body = Data(base64Encoded: bodyData) {
            request.httpBody = body
        }

        let task = URLSession.shared.dataTask(with: request) { [weak self] responseData, response, error in
            guard let self = self else { return }

            if let error = error {
                self.injectCallback("window.__j2meNetworkCallbacks.request",
                                   data: ["error": error.localizedDescription])
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                self.injectCallback("window.__j2meNetworkCallbacks.request",
                                   data: ["error": "Invalid response"])
                return
            }

            var result: [String: Any] = [
                "statusCode": httpResponse.statusCode,
                "headers": httpResponse.allHeaderFields.compactMapKeys { String(describing: $0) }
            ]

            if let data = responseData {
                if responseType == "base64" {
                    result["data"] = data.base64EncodedString()
                } else {
                    result["data"] = String(data: data, encoding: .utf8) ?? ""
                }
                result["encoding"] = responseType
            }

            self.injectCallback("window.__j2meNetworkCallbacks.request", data: result)
        }

        task.resume()
    }

    // MARK: - Socket Operations

    private func handleConnectSocket(_ data: [String: Any], callback: J2MENetworkCallback?) {
        guard let host = data["host"] as? String,
              let port = data["port"] as? Int else {
            callback?(["error": "Invalid socket parameters"])
            return
        }

        // Use socketId from JavaScript if provided, otherwise generate one
        let timeout = (data["timeout"] as? Double) ?? 3000
        let socketId: String
        if let jsSocketId = data["__socketId"] as? String {
            socketId = jsSocketId
        } else {
            socketId = "socket_\(nextSocketId)"
            nextSocketId += 1
        }

        Log.debug("J2MENetworkBridge: connectSocket \(host):\(port) id=\(socketId), active sockets: \(sockets.count), pending: \(pendingConnections.count)")

        // Count active connections to this specific host
        let existingHostSocketIds = hostSockets[host] ?? []
        let activeToHost = existingHostSocketIds.filter { socketId in
            sockets[socketId] != nil
        }.count

        // If we have too many active connections to this host, queue this request
        if activeToHost >= maxConnectionsPerHost {
            Log.debug("J2MENetworkBridge: connection limit reached for \(host):\(port) (\(activeToHost) active), queueing request")
            pendingConnections.append(PendingConnection(data: data, callback: callback, timestamp: Date()))

            // Set up timeout for pending request
            socketQueue.asyncAfter(deadline: .now() + pendingConnectionTimeout) { [weak self] in
                self?.processPendingConnections()
            }
            return
        }

        // Proceed with connection
        createConnection(socketId: socketId, host: host, port: port, timeout: timeout, data: data, callback: callback)
    }

    private func createConnection(socketId: String, host: String, port: Int, timeout: Double, data: [String: Any], callback: J2MENetworkCallback?) {
        // Create TCP connection using Network.framework
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: UInt16(port)))
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true

        let connection = NWConnection(to: endpoint, using: parameters)

        // Store callback
        if let callback = callback {
            socketCallbacks[socketId] = callback
        }

        // Store connection with host tracking
        sockets[socketId] = connection
        if hostSockets[host] == nil {
            hostSockets[host] = []
        }
        hostSockets[host]?.append(socketId)

        // Set up state observer
        connection.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }

            switch state {
            case .ready:
                Log.debug("J2MENetworkBridge: socket \(socketId) connected")
                // Notify connected
                self.injectSocketEvent(socketId, event: "connect")
                // Process any pending connections
                self.processPendingConnections()

            case .failed(let error):
                Log.debug("J2MENetworkBridge: socket \(socketId) failed: \(error)")
                self.injectSocketEvent(socketId, event: "close")
                self.cleanupSocket(socketId)
                self.processPendingConnections()

            case .cancelled:
                Log.debug("J2MENetworkBridge: socket \(socketId) cancelled")
                self.cleanupSocket(socketId)
                self.processPendingConnections()

            case .waiting(let error):
                Log.debug("J2MENetworkBridge: socket \(socketId) waiting: \(error)")

            default:
                break
            }
        }

        // Start connection
        connection.start(queue: socketQueue)

        // Set up data receive handler
        receiveData(for: socketId)

        // Set up timeout
        let deadline = DispatchTime.now() + timeout / 1000.0
        socketQueue.asyncAfter(deadline: deadline) { [weak self] in
            guard let self = self, let conn = self.sockets[socketId] else { return }
            if conn.state != .ready {
                Log.debug("J2MENetworkBridge: socket \(socketId) timeout")
                self.injectSocketEvent(socketId, event: "close")
                conn.cancel()
                self.cleanupSocket(socketId)
                self.processPendingConnections()
            }
        }
    }

    private func processPendingConnections() {
        socketQueue.async { [weak self] in
            guard let self = self else { return }

            // Clean up stale pending requests
            let now = Date()
            self.pendingConnections.removeAll { pending in
                now.timeIntervalSince(pending.timestamp) > self.pendingConnectionTimeout
            }

            // Process pending connections if we have capacity for their specific host
            while !self.pendingConnections.isEmpty {
                // Find the first pending connection that we have capacity for
                guard let index = self.pendingConnections.firstIndex(where: { pending in
                    guard let host = pending.data["host"] as? String else { return false }
                    let existingHostSocketIds = self.hostSockets[host] ?? []
                    let activeToHost = existingHostSocketIds.filter { socketId in
                        self.sockets[socketId] != nil
                    }.count
                    return activeToHost < self.maxConnectionsPerHost
                }) else {
                    // No pending connection fits the per-host limit
                    break
                }

                let pending = self.pendingConnections.remove(at: index)
                guard let host = pending.data["host"] as? String,
                      let port = pending.data["port"] as? Int else {
                    continue
                }

                let timeout = (pending.data["timeout"] as? Double) ?? 3000
                let socketId = "socket_\(self.nextSocketId)"
                self.nextSocketId += 1

                Log.debug("J2MENetworkBridge: processing pending connection to \(host):\(port)")

                self.createConnection(
                    socketId: socketId,
                    host: host,
                    port: port,
                    timeout: timeout,
                    data: pending.data,
                    callback: pending.callback
                )
            }
        }
    }

    private func handleOnSocket(_ data: [String: Any], callback: J2MENetworkCallback?) {
        guard let socketId = data["id"] as? String else {
            callback?(["error": "Missing socket id"])
            return
        }

        // Register the callback for this socket
        if let callback = callback {
            socketCallbacks[socketId] = callback
        }

        // If socket exists and is ready, immediately send connect event
        if let conn = sockets[socketId], conn.state == .ready {
            injectSocketEvent(socketId, event: "connect")
        }
    }

    private func handleInvokeSocket(_ data: [String: Any]) {
        guard let socketId = data["id"] as? String,
              let method = data["method"] as? String else {
            return
        }

        Log.debug("J2MENetworkBridge: invokeSocket \(socketId) method=\(method)")

        switch method {
        case "write":
            guard let base64Data = data["data"] as? String,
                  let writeData = Data(base64Encoded: base64Data) else {
                return
            }

            // 打印发送的数据内容
            var writeStr = "[Binary: \(writeData.count) bytes]"
            if let str = String(data: writeData, encoding: .utf8) {
                writeStr = str
            }
            Log.debug("J2MENetworkBridge: socket \(socketId) WRITE \(writeData.count) bytes:\n\(writeStr)")

            if let connection = sockets[socketId] {
                connection.send(content: writeData, completion: .contentProcessed { error in
                    if let error = error {
                        Log.debug("J2MENetworkBridge: socket \(socketId) write error: \(error)")
                    }
                })
            }

        case "destroy":
            if let connection = sockets[socketId] {
                connection.cancel()
            }
            cleanupSocket(socketId)

        default:
            Log.debug("J2MENetworkBridge: unknown invokeSocket method: \(method)")
        }
    }

    // MARK: - Data Reception

    private func receiveData(for socketId: String) {
        guard let connection = sockets[socketId] else { return }

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            guard let self = self else { return }

            if let data = content, !data.isEmpty {
                let base64 = data.base64EncodedString()
                // 打印接收到的数据内容
                var dataStr = "[Binary data: \(data.count) bytes, hex: \(data.prefix(256).map { String(format: "%02X", $0) }.joined(separator: " "))]"
                if let str = String(data: data, encoding: .utf8) {
                    dataStr = str
                }
                Log.debug("J2MENetworkBridge: socket \(socketId) received \(data.count) bytes, content:\n\(dataStr)")
                self.injectSocketEvent(socketId, event: "data", data: base64)
            }

            if isComplete {
                Log.debug("J2MENetworkBridge: socket \(socketId) closed by remote")
                self.injectSocketEvent(socketId, event: "close")
                self.cleanupSocket(socketId)
            } else if let error = error {
                Log.debug("J2MENetworkBridge: socket \(socketId) receive error: \(error)")
                self.injectSocketEvent(socketId, event: "close")
                self.cleanupSocket(socketId)
            } else {
                // Continue receiving
                self.receiveData(for: socketId)
            }
        }
    }

    // MARK: - Cleanup

    private func cleanupSocket(_ socketId: String) {
        sockets.removeValue(forKey: socketId)
        socketCallbacks.removeValue(forKey: socketId)

        // Remove from hostSockets tracking
        for (host, var socketIds) in hostSockets {
            if socketIds.contains(socketId) {
                socketIds.removeAll { $0 == socketId }
                if socketIds.isEmpty {
                    hostSockets.removeValue(forKey: host)
                } else {
                    hostSockets[host] = socketIds
                }
                break
            }
        }
    }

    // MARK: - JavaScript Injection

    /// Inject a callback result into the WebView JavaScript context
    private func injectCallback(_ callbackName: String, data: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let webView = self.webView else { return }

            let jsonData: Data
            do {
                jsonData = try JSONSerialization.data(withJSONObject: data)
            } catch {
                Log.debug("J2MENetworkBridge: JSON serialization error: \(error)")
                return
            }

            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                return
            }

            let script = """
            (function() {
                var callback = \(callbackName);
                if (typeof callback === 'function') {
                    callback(\(jsonString));
                }
            })();
            """

            webView.evaluateJavaScript(script) { _, error in
                if let error = error {
                    Log.debug("J2MENetworkBridge: evaluateJavaScript error: \(error)")
                }
            }
        }
    }

    /// Inject a socket event into the WebView JavaScript context
    private func injectSocketEvent(_ socketId: String, event: String, data: String? = nil) {
        let callbackKey = "window.__j2meSocketCallbacks[\"\(socketId)\"]"

        var eventData: [String: Any] = ["event": event]
        if let data = data {
            eventData["data"] = data
        }

        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(withJSONObject: eventData)
        } catch {
            Log.debug("J2MENetworkBridge: JSON serialization error: \(error)")
            return
        }

        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }

        Log.debug("J2MENetworkBridge: injectSocketEvent socketId=\(socketId) event=\(event) callbackKey=\(callbackKey) jsonString=\(jsonString)")

        let script = """
        (function() {
            var callback = \(callbackKey);
            console.log('[JS] Looking up callback for key: \(callbackKey)');
            console.log('[JS] callback type:', typeof callback);
            if (typeof callback === 'function') {
                console.log('[JS] Calling callback with:', \(jsonString));
                callback(\(jsonString));
                console.log('[JS] Callback called successfully');
            } else {
                console.log('[JS] Callback not found or not a function');
            }
        })();
        """

        DispatchQueue.main.async { [weak self] in
            guard let self = self, let webView = self.webView else { return }

            webView.evaluateJavaScript(script) { _, error in
                if let error = error {
                    Log.debug("J2MENetworkBridge: socket event injection error: \(error)")
                }
            }
        }
    }
}

// MARK: - Dictionary Extension

private extension Dictionary {
    /// Creates a new dictionary with keys transformed to Strings
    func compactMapKeys<T: Hashable>(_ transform: (Key) throws -> T?) rethrows -> [T: Value] {
        var result: [T: Value] = [:]
        for (key, value) in self {
            if let newKey = try transform(key) {
                result[newKey] = value
            }
        }
        return result
    }
}
