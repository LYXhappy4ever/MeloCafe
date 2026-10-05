//
//  AccountEditorView.swift
//  MeloCafe
//
//  Created by Stossy11 on 14/9/2026.
//

import SwiftUI

enum Gender: Int, CaseIterable {
    case female = 0
    case male = 1

    var title: String { self == .female ? "女" : "男" }
}

struct AccountEditorView: View {
    let account: Account

    var body: some View {
        Form {
            Section("账户信息") {
                AccountInformationFields(account: account)
            }
        }
        .navigationTitle("账户信息")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AccountInformationFields: View {
    @ObservedObject private var configManager = ConfigManager.shared
    let account: Account
    @State private var name: String
    @State private var email: String
    @State private var birthday: String
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?
    @State private var previousField: Field?

    private enum Field: Hashable { case name, birthday, email }

    init(account: Account) {
        self.account = account
        _name = State(initialValue: account.miiName)
        _email = State(initialValue: account.email)
        _birthday = State(initialValue: Self.birthdayString(account))
    }

    private var currentAccount: Account {
        configManager.accounts.first { $0.persistentId == account.persistentId } ?? account
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("持久 ID")
                Spacer()
                Text(account.persistentIdHex)
                    .font(.body.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .accessibilityHint("持久 ID 是保存存档的内部文件夹名称")

            HStack {
                Text("Mii 名称")
                TextField("Mii 名称", text: $name)
                    .multilineTextAlignment(.trailing)
                    .focused($focusedField, equals: .name)
                    .onChange(of: name) { name = String($0.prefix(10)) }
            }
            .accessibilityHint("Mii 名称是账户显示名称")

            HStack {
                Text("生日")
                TextField("YYYY-MM-DD", text: $birthday)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numbersAndPunctuation)
                    .focused($focusedField, equals: .birthday)
            }

            Picker("性别", selection: Binding(
                get: { Gender(rawValue: currentAccount.gender) ?? .male },
                set: { reportSave(configManager.setGender($0.rawValue, for: account.persistentId)) }
            )) {
                ForEach(Gender.allCases, id: \.self) { gender in
                    Text(gender.title).tag(gender)
                }
            }
            .pickerStyle(.menu)

            HStack {
                Text("电子邮箱")
                TextField("电子邮箱", text: $email)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
            }

            Picker("国家或地区", selection: Binding(
                get: { configManager.accountCountries.contains { $0.code == currentAccount.country } ? currentAccount.country : 0 },
                set: { reportSave(configManager.setCountry($0, for: account.persistentId)) }
            )) {
                ForEach(configManager.accountCountries) { country in
                    Text(country.name).tag(country.code)
                }
            }
            .pickerStyle(.menu)
        }
        .onSubmit { focusedField = nil }
        .onChange(of: focusedField) { newField in
            let fieldToSave = previousField
            previousField = newField
            if let fieldToSave = fieldToSave { save(fieldToSave) }
        }
        .onDisappear {
            if let field = previousField {
                previousField = nil
                save(field)
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
    }

    private func save(_ field: Field) {
        switch field {
        case .name:
            guard name != currentAccount.miiName else { return }
            reportSave(configManager.setMiiName(name, for: account.persistentId))
            name = currentAccount.miiName
        case .email:
            guard email != currentAccount.email else { return }
            reportSave(configManager.setEmail(email, for: account.persistentId))
            email = currentAccount.email
        case .birthday:
            guard birthday != Self.birthdayString(currentAccount) else { return }
            let tokens = birthday.split(separator: "-", omittingEmptySubsequences: false)
            if tokens.count == 3, let year = UInt16(tokens[0]), let month = UInt8(tokens[1]), let day = UInt8(tokens[2]) {
                reportSave(configManager.setBirthDate(year: year, month: month, day: day, for: account.persistentId))
            } else {
                errorMessage = "请按 YYYY-MM-DD 格式输入生日。"
            }
            birthday = Self.birthdayString(currentAccount)
        }
    }

    private func reportSave(_ success: Bool) {
        if !success { errorMessage = "无法保存账户信息。" }
    }

    private static func birthdayString(_ account: Account) -> String {
        String(format: "%04d-%02d-%02d", Int(account.birthYear), Int(account.birthMonth), Int(account.birthDay))
    }
}
