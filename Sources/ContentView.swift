import SwiftUI

struct ContentView: View {
    @StateObject private var session = SSHSession()
    @State private var hosts: [SSHHost] = SSHHostStore.load()
    @State private var selectedID: UUID?
    @State private var editingHost: SSHHost?
    @State private var password = ""
    @State private var command = ""
    @FocusState private var commandFocused: Bool

    private var selectedHost: SSHHost? { hosts.first(where: { $0.id == selectedID }) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                if !session.connected {
                    HStack {
                        Text("我的服务器").font(.headline)
                        Spacer()
                        Button {
                            editingHost = SSHHost()
                        } label: {
                            Label("新增", systemImage: "plus")
                        }
                    }
                    if hosts.isEmpty {
                        ContentUnavailableView("还没有服务器", systemImage: "server.rack", description: Text("点击新增，保存 VPS 连接信息"))
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(hosts) { host in
                                    HStack(spacing: 10) {
                                        Button {
                                            select(host)
                                        } label: {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(host.displayName).font(.headline)
                                                Text("\(host.username)@\(host.address):\(host.port)")
                                                    .font(.caption.monospaced())
                                                    .foregroundStyle(.secondary)
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .buttonStyle(.plain)
                                        Button {
                                            editingHost = host
                                        } label: {
                                            Image(systemName: "pencil").padding(8)
                                        }
                                        .accessibilityLabel("编辑 \(host.displayName)")
                                    }
                                    .padding(12)
                                    .background(selectedID == host.id ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                        .frame(maxHeight: 190)
                        if let selectedHost {
                            SecureField("SSH 密码", text: $password)
                                .textFieldStyle(.roundedBorder)
                            Button(session.busy ? "连接中…" : "连接 \(selectedHost.displayName)") {
                                connect(selectedHost)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(session.busy || selectedHost.address.isEmpty || password.isEmpty)
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text(selectedHost?.displayName ?? "已连接").font(.subheadline)
                        Spacer()
                        Button("断开") {
                            commandFocused = false
                            Task { await session.disconnect() }
                        }
                    }
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        Text(session.log.isEmpty ? "SSH 命令输出将显示在这里" : session.log)
                            .font(.system(size: 13, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                        Color.clear.frame(height: 1).id("end")
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { commandFocused = false }
                    .padding(12)
                    .background(Color(red: 0.07, green: 0.09, blue: 0.12))
                    .foregroundStyle(.green)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onChange(of: session.log) {
                        proxy.scrollTo("end", anchor: .bottom)
                    }
                }

                if session.connected {
                    HStack {
                        TextField("点击输入命令", text: $command)
                            .font(.system(.body, design: .monospaced))
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.send)
                            .focused($commandFocused)
                            .onSubmit(send)
                        Button("执行", action: send)
                            .buttonStyle(.borderedProminent)
                            .disabled(session.busy || command.isEmpty)
                    }
                }
            }
            .padding()
            .navigationTitle("MySSH")
            .onAppear {
                if selectedID == nil {
                    if let last = UserDefaults.standard.string(forKey: "ssh.lastHostID"),
                       let id = UUID(uuidString: last),
                       hosts.contains(where: { $0.id == id }) {
                        selectedID = id
                    } else {
                        selectedID = hosts.first?.id
                    }
                }
                if let selectedHost { password = SSHPasswordStore.load(account: selectedHost.credentialAccount) }
                commandFocused = false
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("清屏") { session.clear() }
                }
            }
            .sheet(item: $editingHost) { host in
                HostEditor(host: host, onSave: { updated, secret in
                    if let index = hosts.firstIndex(where: { $0.id == updated.id }) {
                        hosts[index] = updated
                    } else {
                        hosts.append(updated)
                    }
                    SSHHostStore.save(hosts)
                    if !secret.isEmpty { _ = SSHPasswordStore.save(secret, account: updated.credentialAccount) }
                    select(updated)
                    editingHost = nil
                }, onDelete: {
                    hosts.removeAll(where: { $0.id == host.id })
                    SSHHostStore.save(hosts)
                    _ = SSHPasswordStore.save("", account: host.credentialAccount)
                    selectedID = nil
                    password = ""
                    if let first = hosts.first { select(first) }
                    editingHost = nil
                }, onCancel: { editingHost = nil })
            }
        }
    }

    private func select(_ host: SSHHost) {
        selectedID = host.id
        UserDefaults.standard.set(host.id.uuidString, forKey: "ssh.lastHostID")
        password = SSHPasswordStore.load(account: host.credentialAccount)
        commandFocused = false
    }

    private func connect(_ host: SSHHost) {
        guard let port = Int(host.port), (1...65535).contains(port) else { return }
        _ = SSHPasswordStore.save(password, account: host.credentialAccount)
        commandFocused = false
        Task { await session.connect(host: host.address.trimmingCharacters(in: .whitespacesAndNewlines),
                                     port: port, user: host.username, password: password) }
    }

    private func send() {
        guard !session.busy else { return }
        let value = command
        command = ""
        commandFocused = false
        Task { await session.run(value) }
    }
}

private struct HostEditor: View {
    @State var host: SSHHost
    @State private var password: String
    let onSave: (SSHHost, String) -> Void
    let onDelete: () -> Void
    let onCancel: () -> Void

    init(host: SSHHost, onSave: @escaping (SSHHost, String) -> Void, onDelete: @escaping () -> Void, onCancel: @escaping () -> Void) {
        _host = State(initialValue: host)
        _password = State(initialValue: SSHPasswordStore.load(account: host.credentialAccount))
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("名称（例如：大阪 VPS）", text: $host.name)
                TextField("IP 或域名", text: $host.address)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("端口", text: $host.port)
                    .keyboardType(.numberPad)
                TextField("用户名", text: $host.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("密码", text: $password)
                Button("删除此服务器", role: .destructive, action: onDelete)
            }
            .navigationTitle("服务器配置")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("取消", action: onCancel) }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { onSave(host, password) }
                        .disabled(host.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                  host.username.isEmpty || !(1...65535).contains(Int(host.port) ?? 0))
                }
            }
        }
    }
}
