//
//  AccountEditorView.swift
//  MeloCafe
//
//  Created by Stossy11 on 14/9/2026.
//

import SwiftUI

struct AccountSettingsView: View {
    @ObservedObject private var configManager = ConfigManager.shared
    @State private var showingCreateAccount = false
    @State private var accountToDelete: Account?
    @State private var errorMessage: String?
    @State private var onlineDetails: String?
    @State private var informationExpanded = false
    @State private var onlineValid = false
    @State private var onlineStatus = "未选择账户"

    var body: some View {
        Form {
            Section("账户") {
                Picker("当前账户", selection: Binding(
                    get: { configManager.activeAccountPersistentId },
                    set: { configManager.setActiveAccount($0) }
                )) {
                    ForEach(configManager.accounts) { account in
                        Text(account.displayNameWithId).tag(account.persistentId)
                    }
                }
                .pickerStyle(.menu)
                .disabled(configManager.accountControlsLocked || configManager.accounts.isEmpty)

                HStack {
                    Button("创建") { showingCreateAccount = true }
                        .disabled(!configManager.canCreateAccount)
                        .sheet(isPresented: $showingCreateAccount) {
                            CreateAccountView()
                        }
                    Spacer()
                    Button("删除", role: .destructive) { accountToDelete = configManager.activeAccount }
                        .disabled(!configManager.canDeleteSelectedAccount)
                }
                .buttonStyle(.borderless)
            }

            Section {
                ForEach(NetworkService.allCases) { service in
                    Button {
                        configManager.networkService.wrappedValue = service
                    } label: {
                        HStack {
                            Text(service.accountTitle)
                            Spacer()
                            if (onlineValid ? configManager.networkService.wrappedValue : .offline) == service {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .disabled(!onlineValid || configManager.accountControlsLocked ||
                              (service == .custom && !configManager.customNetworkServiceAvailable))
                    .accessibilityHint(service.accountHelp)
                }
            } header: {
                Text("网络服务\(configManager.activeAccount.map { " (\($0.displayName))" } ?? "")")
            } footer: {
                Text((onlineValid ? configManager.networkService.wrappedValue : .offline).accountHelp)
            }

            Section("联机条件") {
                Button {
                    if let account = configManager.activeAccount {
                        onlineDetails = configManager.onlineValidationDetails(for: account.persistentId)
                    }
                } label: {
                    Label {
                        Text(onlineStatus).foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: onlineValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundStyle(onlineValid ? .green : .red)
                    }
                }
                .disabled(configManager.activeAccount == nil)
                Link("联机教程", destination: URL(string: "https://cemu.info/online-guide")!)
            }

            Section {
                DisclosureGroup("账户信息", isExpanded: $informationExpanded) {
                    if let account = configManager.activeAccount {
                        AccountInformationFields(account: account)
                            .id(account.persistentId)
                            .padding(.vertical, 8)
                    } else {
                        Text("未选择账户").foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("账户")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            configManager.reloadAccounts()
            refreshOnlineStatus()
        }
        .onChange(of: configManager.activeAccountPersistentId) { _ in refreshOnlineStatus() }
        .onChange(of: configManager.accounts) { _ in refreshOnlineStatus() }
        .alert("确认", isPresented: Binding(
            get: { accountToDelete != nil },
            set: { if !$0 { accountToDelete = nil } }
        )) {
            Button("是", role: .destructive) {
                if let account = accountToDelete {
                    errorMessage = configManager.deleteAccount(persistentId: account.persistentId)
                }
                accountToDelete = nil
            }
            Button("否", role: .cancel) { accountToDelete = nil }
        } message: {
            if let account = accountToDelete {
                Text("确定删除账户 \(account.displayName)（ID：\(account.persistentIdHex)）吗？")
            }
        }
        .alert("错误", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("联机状态", isPresented: Binding(
            get: { onlineDetails != nil },
            set: { if !$0 { onlineDetails = nil } }
        )) {
            Button("确定", role: .cancel) { onlineDetails = nil }
        } message: {
            Text(onlineDetails ?? "")
        }
    }

    private func refreshOnlineStatus() {
        guard let account = configManager.activeAccount else {
            onlineValid = false
            onlineStatus = "未选择账户"
            return
        }
        onlineValid = configManager.isOnlineFullyValid(for: account.persistentId)
        onlineStatus = configManager.onlineStatus(for: account.persistentId)
    }
}

private extension NetworkService {
    var accountTitle: String {
        switch self {
        case .offline: return "离线"
        case .nintendo: return "Nintendo"
        case .pretendo: return "Pretendo"
        case .custom: return "自定义"
        }
    }

    var accountHelp: String {
        switch self {
        case .offline: return "此账户已禁用联机功能"
        case .nintendo: return "连接任天堂官方网络服务"
        case .pretendo: return "连接 Pretendo 网络服务"
        case .custom: return "连接自定义网络服务（通过 network_services.xml 配置）"
        }
    }
}
