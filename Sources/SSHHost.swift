import Foundation

struct SSHHost: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var address: String
    var port: String
    var username: String

    init(id: UUID = UUID(), name: String = "", address: String = "", port: String = "22", username: String = "root") {
        self.id = id
        self.name = name
        self.address = address
        self.port = port
        self.username = username
    }

    var credentialAccount: String { id.uuidString }
    var displayName: String { name.isEmpty ? address : name }
}

enum SSHHostStore {
    private static let key = "ssh.savedHosts.v1"
    static func load() -> [SSHHost] {
        if let data = UserDefaults.standard.data(forKey: key),
           let hosts = try? JSONDecoder().decode([SSHHost].self, from: data) { return hosts }
        let oldAddress = UserDefaults.standard.string(forKey: "ssh.host") ?? ""
        guard !oldAddress.isEmpty else { return [] }
        let oldPort = UserDefaults.standard.string(forKey: "ssh.port") ?? "22"
        let oldUser = UserDefaults.standard.string(forKey: "ssh.username") ?? "root"
        let migrated = SSHHost(name: "我的 VPS", address: oldAddress, port: oldPort, username: oldUser)
        let oldAccount = "\(oldUser)@\(oldAddress):\(oldPort)"
        let oldPassword = SSHPasswordStore.load(account: oldAccount)
        if !oldPassword.isEmpty { _ = SSHPasswordStore.save(oldPassword, account: migrated.credentialAccount) }
        save([migrated])
        return [migrated]
    }
    static func save(_ hosts: [SSHHost]) {
        guard let data = try? JSONEncoder().encode(hosts) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
