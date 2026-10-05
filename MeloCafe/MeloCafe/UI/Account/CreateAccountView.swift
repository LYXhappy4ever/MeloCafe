//
//  CreateAccountView.swift
//  MeloCafe
//
//  Created by Stossy11 on 10/9/2026.
//

import SwiftUI

struct CreateAccountView: View {
    @StateObject private var configManager = ConfigManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var persistentIdText: String
    @State private var miiName = ""
    @State private var errorMessage: String?
    @FocusState private var nameFocused: Bool
    
    init() {
        _persistentIdText = State(initialValue: String(ConfigManager.shared.nextAccountPersistentId, radix: 16))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("持久 ID")
                        TextField("持久 ID", text: $persistentIdText)
                            .multilineTextAlignment(.trailing)
                            .font(.body.monospaced())
                            .keyboardType(.asciiCapable)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    HStack {
                        Text("Mii 名称")
                        TextField("Mii 名称", text: $miiName)
                            .multilineTextAlignment(.trailing)
                            .focused($nameFocused)
                            .submitLabel(.done)
                            .onSubmit { createAccount() }
                    }
                        .onChange(of: miiName) { newValue in
                            let trimmedName = String(newValue.prefix(10))
                            if trimmedName != newValue {
                                miiName = trimmedName
                            }
                        }
                } footer: {
                    Text("持久 ID 是保存存档的内部文件夹名称。仅在导入具有特定 ID 的 Wii U 存档时修改。")
                }
            }
            .navigationTitle("创建新账户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        createAccount()
                    }
                }
            }
        }
        .frame(idealWidth: 440, idealHeight: 320)
        .onAppear { nameFocused = true }
        .alert("错误", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    private func createAccount() {
        let idString = persistentIdText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !idString.isEmpty else {
            errorMessage = "未输入持久 ID！"
            return
        }
        
        guard configManager.canCreateAccount else {
            errorMessage = configManager.accountControlsLocked ? "游戏运行期间无法创建账户！" : "已达到账户数量上限。"
            return
        }
        guard let persistentId = UInt32(idString, radix: 16) else {
            errorMessage = "请输入有效的十六进制持久 ID。"
            return
        }
        guard persistentId >= configManager.minimumAccountPersistentId else {
            errorMessage = "The persistent id must be greater than \(String(configManager.minimumAccountPersistentId, radix: 16))!"
            return
        }
        
        if configManager.accountExists(persistentId: persistentId) {
            let accountName = configManager.accounts
                .first(where: { $0.persistentId == persistentId })?
                .displayName ?? "unknown"
            errorMessage = "The persistent id \(String(persistentId, radix: 16)) is already in use by account \(accountName)!"
            return
        }
        
        guard !miiName.isEmpty else {
            errorMessage = "账户名称不能为空！"
            return
        }
        
        if let error = configManager.createAccount(persistentId: persistentId, miiName: miiName) {
            errorMessage = error
            return
        }
        
        dismiss()
    }
}
