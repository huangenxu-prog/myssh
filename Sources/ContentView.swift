import SwiftUI

struct ContentView: View {
    @StateObject private var session = SSHSession()
    @State private var host = ""
    @State private var port = "22"
    @State private var username = "root"
    @State private var password = ""
    @State private var command = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                if !session.connected {
                    VStack(spacing: 10) {
                        TextField("VPS IP 或域名", text: $host)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("SSH 端口", text: $port)
                            .keyboardType(.numberPad)
                        TextField("用户名", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        SecureField("SSH 密码", text: $password)
                        Button(session.busy ? "连接中…" : "连接 VPS") {
                            Task {
                                await session.connect(host: host.trimmingCharacters(in: .whitespacesAndNewlines),
                                                      port: Int(port) ?? 22,
                                                      user: username, password: password)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                        .disabled(host.isEmpty || username.isEmpty || session.busy)
                    }
                    .textFieldStyle(.roundedBorder)
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        Text(session.log.isEmpty ? "SSH 命令输出将显示在这里" : session.log)
                            .font(.system(size: 13, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                        Color.clear.frame(height: 1).id("end")
                    }
                    .padding(12)
                    .background(Color(red: 0.07, green: 0.09, blue: 0.12))
                    .foregroundStyle(.green)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onChange(of: session.log) { _ in
                        withAnimation { proxy.scrollTo("end", anchor: .bottom) }
                    }
                }

                if session.connected {
                    HStack {
                        TextField("输入命令，例如 ls -la", text: $command)
                            .font(.system(.body, design: .monospaced))
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.send)
                            .onSubmit(send)
                        Button("执行", action: send)
                            .buttonStyle(.borderedProminent)
                            .disabled(session.busy || command.isEmpty)
                    }
                }
            }
            .padding()
            .navigationTitle("MySSH")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("清屏") { session.clear() }
                    if session.connected {
                        Button("断开") { Task { await session.disconnect() } }
                    }
                }
            }
        }
    }

    private func send() {
        guard !session.busy else { return }
        let value = command
        command = ""
        Task { await session.run(value) }
    }
}
