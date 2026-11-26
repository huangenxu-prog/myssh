import SwiftUI

struct ContentView: View {
    @StateObject private var session = SSHSession()
    @State private var hosts: [SSHHost] = SSHHostStore.load()
    @State private var selectedID: UUID?
    @State private var editingHost: SSHHost?
    @State private var missingPassword = false
    @State private var showDeleteConfirmation = false
    @State private var pendingDeleteID: UUID?
    @State private var command = ""
    @FocusState private var commandFocused: Bool

    private var selectedHost: SSHHost? { hosts.first(where: { $0.id == selectedID }) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                if !session.connected {
                    HStack {
                        Text("我的服务器").font(.title3.bold())
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
                                    HStack(spacing: 12) {
                                        Image(systemName: "server.rack")
                                            .font(.title3)
                                            .foregroundStyle(selectedID == host.id ? Color.blue : Color.secondary)
                                            .frame(width: 30)
                                        Button {
                                            select(host)
                                        } label: {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(host.displayName).font(.headline)
                                                    .foregroundStyle(.primary)
                                                Text("\(host.address):\(host.port) · \(host.username)")
                                                    .font(.caption.monospaced())
                                                    .foregroundStyle(.secondary)
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .buttonStyle(.plain)
                                        if selectedID == host.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.blue)
                                        }
                                        Menu {
                                            Button("编辑", systemImage: "pencil") { editingHost = host }
                                            Button("复制主机信息", systemImage: "doc.on.doc") {
                                                UIPasteboard.general.string = "\(host.username)@\(host.address):\(host.port)"
                                            }
                                            Button("上移", systemImage: "arrow.up") { move(host, offset: -1) }
                                            Button("下移", systemImage: "arrow.down") { move(host, offset: 1) }
                                            Button("删除", systemImage: "trash", role: .destructive) {
                                                pendingDeleteID = host.id
                                                showDeleteConfirmation = true
                                            }
                                        } label: {
                                            Image(systemName: "ellipsis")
                                                .font(.headline)
                                                .frame(width: 38, height: 38)
                                                .background(.thinMaterial, in: Circle())
                                        }
                                        .accessibilityLabel("管理 \(host.displayName)")
                                    }
                                    .padding(14)
                                    .background(selectedID == host.id ? Color.blue.opacity(0.12) : Color.secondary.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                        .frame(maxHeight: 290)
                        if let selectedHost {
                            Button {
                                connect(selectedHost)
                            } label: {
                                Label(session.busy ? "连接中…" : "连接 \(selectedHost.displayName)", systemImage: "link")
                                    .font(.headline)
                                    .frame(minWidth: 180)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(session.busy || selectedHost.address.isEmpty)
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
                        ZStack(alignment: .topLeading) {
                            if command.isEmpty {
                                Text("点击输入命令")
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 8)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $command)
                                .scrollContentBackground(.hidden)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($commandFocused)
                                .padding(.horizontal, 4)
                        }
                        .font(.system(.body, design: .monospaced))
                        .frame(height: CGFloat(min(6, max(1, command.components(separatedBy: .newlines).count))) * 22 + 18)
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.secondary.opacity(0.25)))
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
                commandFocused = false
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("清屏") { session.clear() }
                }
            }
            .confirmationDialog("删除这台服务器？", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("删除服务器", role: .destructive) {
                    if let id = pendingDeleteID { deleteHost(id) }
                }
            }
            .alert("未保存 SSH 密码", isPresented: $missingPassword) {
                Button("去编辑") { editingHost = selectedHost }
                Button("取消", role: .cancel) { }
            } message: {
                Text("请在服务器配置中填写并保存密码。")
            }
            .sheet(item: $editingHost) { host in
                HostEditor(host: host, onSave: { updated, secret in
                    if let index = hosts.firstIndex(where: { $0.id == updated.id }) {
                        hosts[index] = updated
                    } else {
                        hosts.append(updated)
                    }
                    SSHHostStore.save(hosts)
                    _ = SSHPasswordStore.save(secret, account: updated.credentialAccount)
                    select(updated)
                    editingHost = nil
                }, onDelete: {
                    hosts.removeAll(where: { $0.id == host.id })
                    SSHHostStore.save(hosts)
                    _ = SSHPasswordStore.save("", account: host.credentialAccount)
                    selectedID = nil
                    if let first = hosts.first { select(first) }
                    editingHost = nil
                }, onCancel: { editingHost = nil })
            }
        }
    }

    private func move(_ host: SSHHost, offset: Int) {
        guard let index = hosts.firstIndex(where: { $0.id == host.id }),
              hosts.indices.contains(index + offset) else { return }
        hosts.swapAt(index, index + offset)
        SSHHostStore.save(hosts)
    }

    private func deleteHost(_ id: UUID) {
        hosts.removeAll(where: { $0.id == id })
        SSHHostStore.save(hosts)
        _ = SSHPasswordStore.save("", account: id.uuidString)
        if selectedID == id {
            selectedID = nil
            if let first = hosts.first { select(first) }
        }
    }

    private func select(_ host: SSHHost) {
        selectedID = host.id
        UserDefaults.standard.set(host.id.uuidString, forKey: "ssh.lastHostID")
        commandFocused = false
    }

    private func connect(_ host: SSHHost) {
        guard let port = Int(host.port), (1...65535).contains(port) else { return }
        let savedPassword = SSHPasswordStore.load(account: host.credentialAccount)
        guard !savedPassword.isEmpty else {
            missingPassword = true
            return
        }
        commandFocused = false
        Task { await session.connect(host: host.address.trimmingCharacters(in: .whitespacesAndNewlines),
                                     port: port, user: host.username, password: savedPassword) }
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
                if !host.address.isEmpty {
                    Button("删除此服务器", role: .destructive, action: onDelete)
                }
            }
            .navigationTitle("编辑服务器")
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
