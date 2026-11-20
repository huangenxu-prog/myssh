import Foundation
import Citadel
import NIOCore

@MainActor
final class SSHSession: ObservableObject {
    @Published private(set) var log = ""
    @Published private(set) var connected = false
    @Published private(set) var busy = false
    private var client: SSHClient?

    func connect(host: String, port: Int, user: String, password: String) async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        guard !host.isEmpty, (1...65535).contains(port), !user.isEmpty else {
            log += "请填写有效的主机、端口和用户名\n"
            return
        }
        do {
            // TODO: replace permissive host-key handling with TOFU fingerprint verification.
            let newClient = try await SSHClient.connect(
                host: host,
                port: port,
                authenticationMethod: .passwordBased(username: user, password: password),
                hostKeyValidator: .acceptAnything(),
                reconnect: .never
            )
            client = newClient
            connected = true
            log += "已连接 \(user)@\(host):\(port)\n"
        } catch {
            connected = false
            client = nil
            log += "连接失败：\(error.localizedDescription)\n"
        }
    }

    func run(_ command: String) async {
        guard !busy, let client, !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        busy = true
        defer { busy = false }
        log += "$ \(command)\n"
        do {
            let output = try await client.executeCommand(command)
            log += String(buffer: output) + "\n"
        } catch {
            log += "执行失败：\(error.localizedDescription)\n"
        }
    }

    func disconnect() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        try? await client?.close()
        client = nil
        connected = false
        log += "连接已断开\n"
    }

    func clear() { log = "" }
}
