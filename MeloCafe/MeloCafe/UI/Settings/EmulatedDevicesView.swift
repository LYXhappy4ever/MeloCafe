//
//  EmulatedDevicesView.swift
//  MeloCafe
//
//  Created by Stossy11 on 14/9/2026.
//

import SwiftUI
import UniformTypeIdentifiers

enum EmulatedDevice: Int, CaseIterable, Identifiable {
    case skylanders, infinity, dimensions
    
    var id: Int { rawValue }
    var bridge: CemuUSBDevice { CemuUSBDevice(rawValue: rawValue)! }
    
    var name: String {
        switch self {
        case .skylanders: return "Skylanders 传送门"
        case .infinity: return "迪士尼无限底座"
        case .dimensions: return "乐高次元玩具底座"
        }
    }
    
    var fileExtension: String { self == .skylanders ? "sky" : "bin" }
    
    var slotLabels: [String] {
        switch self {
        case .skylanders:
            return (1...16).map { "Skylander 玩偶 \($0)" }
        case .infinity:
            return ["场景套装 / 能量圆盘", "能量圆盘 2", "能量圆盘 3",
                    "玩家 1", "玩家 1 技能 1", "玩家 1 技能 2",
                    "玩家 2", "玩家 2 技能 1", "玩家 2 技能 2"]
        case .dimensions:
            return ["左侧底座：顶部", "中央底座", "右侧底座：顶部",
                    "左侧底座：左下", "左侧底座：右下",
                    "右侧底座：左下", "右侧底座：右下"]
        }
    }
    
    var enabled: Binding<Bool> {
        switch self {
        case .skylanders: return ConfigManager.shared.emulateSkylanderPortal
        case .infinity: return ConfigManager.shared.emulateInfinityBase
        case .dimensions: return ConfigManager.shared.emulateDimensionsToypad
        }
    }
}

struct EmulatedDevicesView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var configManager = ConfigManager.shared
    @State private var device = EmulatedDevice.skylanders
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("设备", selection: $device) {
                        ForEach(EmulatedDevice.allCases) { device in
                            Text(device.name).tag(device)
                        }
                    }
                    Toggle("模拟此设备", isOn: device.enabled)
                }
                
                EmulatedDeviceSlotsView(device: device)
                    .id(device)
            }
            .navigationTitle("模拟外设")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .onAppear {
            device = EmulatedDevice.allCases.first { $0.enabled.wrappedValue } ?? .skylanders
        }
    }
}

private struct EmulatedDeviceSlotsView: View {
    let device: EmulatedDevice
    @State private var names: [String] = []
    @State private var errorMessage: String?
    
    var body: some View {
        Section {
            ForEach(device.slotLabels.indices, id: \.self) { slot in
                VStack(alignment: .leading, spacing: 8) {
                    Text(device.slotLabels[slot])
                        .font(.subheadline.weight(.semibold))
                    Text(name(at: slot).isEmpty ? "无" : name(at: slot))
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 20) {
                        Button("加载") { load(slot: slot) }
                        NavigationLink("创建") {
                            CreateEmulatedFigureView(device: device, slot: slot) { refresh() }
                        }
                        if device == .dimensions {
                            Menu("移动") {
                                ForEach(device.slotLabels.indices, id: \.self) { destination in
                                    if destination != slot && name(at: destination).isEmpty {
                                        Button(device.slotLabels[destination]) {
                                            errorMessage = CemuEmulatedUSBDevices.moveDimensions(from: slot, to: destination)
                                            refresh()
                                        }
                                    }
                                }
                            }
                            .disabled(name(at: slot).isEmpty || !names.contains(""))
                        }
                        Spacer(minLength: 0)
                        Button("清除", role: .destructive) {
                            errorMessage = CemuEmulatedUSBDevices.clear(device.bridge, slot: slot)
                            refresh()
                        }
                        .disabled(name(at: slot).isEmpty)
                    }
                    .buttonStyle(.borderless)
                    .font(.subheadline)
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("玩偶")
        } footer: {
            Text("加载 .\(device.fileExtension) 玩偶数据或创建玩偶。文件和游戏进度保存在 Documents/Emulated Devices 中。清除操作会从设备中移除玩偶并保留文件。")
        }
        .onAppear { refresh() }
        .alert("模拟外设", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    private func name(at slot: Int) -> String {
        names.indices.contains(slot) ? names[slot] : ""
    }
    
    private func refresh() {
        names = CemuEmulatedUSBDevices.slotNames(for: device.bridge)
    }
    
    private func load(slot: Int) {
        FileImporterManager.shared.importFiles(types: [.item]) { result in
            switch result {
            case .success(let urls):
                guard let source = urls.first else { return }
                do {
                    let file = try EmulatedFigureFiles.importFigure(source, device: device)
                    errorMessage = CemuEmulatedUSBDevices.load(device.bridge, slot: slot, path: file.path)
                    refresh()
                } catch {
                    errorMessage = error.localizedDescription
                }
            case .failure(let error):
                let error = error as NSError
                if error.domain != "FileImporterManager" || error.code != 2 {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

private struct CreateEmulatedFigureView: View {
    let device: EmulatedDevice
    let slot: Int
    let onCreated: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var figures: [CemuUSBFigure] = []
    @State private var selectedName = "选择玩偶"
    @State private var figureID = ""
    @State private var variant = "0"
    @State private var fileName = ""
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("玩偶") {
                NavigationLink {
                    EmulatedFigurePicker(figures: figures) { figure in
                        selectedName = figure.name
                        figureID = String(figure.figureID)
                        variant = String(figure.variant)
                        fileName = figure.name
                    }
                } label: {
                    Text(selectedName)
                }
                
                TextField("玩偶 ID", text: $figureID)
                    .keyboardType(.numberPad)
                if device == .skylanders {
                    TextField("变体", text: $variant)
                        .keyboardType(.numberPad)
                }
            }
            Section {
                TextField("文件名", text: $fileName)
                    .autocorrectionDisabled()
            } footer: {
                Text("新的 .\(device.fileExtension) 文件将保存在 Documents/Emulated Devices 中，并加载到 \(device.slotLabels[slot])。")
            }
            if device == .dimensions {
                Section {
                    Text("使用玩偶 ID 0 创建空白载具或道具标签，供游戏写入数据。")
                        .foregroundStyle(.secondary)
                }
            }
            if let errorMessage = errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("创建玩偶")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("创建") { create() }
                    .disabled(figureID.isEmpty)
            }
        }
        .onAppear {
            if figures.isEmpty {
                figures = CemuEmulatedUSBDevices.figures(for: device.bridge, slot: slot)
            }
        }
    }

    private func create() {
        guard let id = UInt32(figureID), device == .infinity || id <= UInt16.max else {
            errorMessage = device == .infinity ? "请输入有效的 32 位玩偶 ID。" : "请输入 0 至 65535 之间的玩偶 ID。"
            return
        }
        guard let variantNumber = UInt16(variant) else {
            errorMessage = "请输入 0 至 65535 之间的变体编号。"
            return
        }
        do {
            let file = try EmulatedFigureFiles.newFile(device: device, name: fileName.isEmpty ? "玩偶 \(id)" : fileName)
            if let error = CemuEmulatedUSBDevices.create(device.bridge, figureID: id, variant: variantNumber, path: file.path) {
                errorMessage = error
                return
            }
            
            if let error = CemuEmulatedUSBDevices.load(device.bridge, slot: slot, path: file.path) {
                errorMessage = "玩偶已保存，但无法加载：\(error)"
                return
            }
            
            onCreated()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct EmulatedFigurePicker: View {
    let figures: [CemuUSBFigure]
    let onSelect: (CemuUSBFigure) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var filteredFigures: [CemuUSBFigure] {
        figures.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || String($0.figureID).contains(search) }
    }

    var body: some View {
        List(filteredFigures, id: \.self) { figure in
            Button {
                onSelect(figure)
                dismiss()
            } label: {
                VStack(alignment: .leading) {
                    Text(figure.name)
                    Text("ID：\(figure.figureID)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("选择玩偶")
        .searchable(text: $search, prompt: "搜索名称或 ID")
    }
}

private enum EmulatedFigureFiles {
    private static func directory(device: EmulatedDevice) throws -> URL {
        let documents = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        
        let folder = documents.appendingPathComponent("模拟外设", isDirectory: true).appendingPathComponent(device.name, isDirectory: true)
        
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        
        return folder
    }
    
    static func newFile(device: EmulatedDevice, name: String) throws -> URL {
        let folder = try directory(device: device).appendingPathComponent(UUID().uuidString, isDirectory: true)
        
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        
        let safeName = name.components(separatedBy: CharacterSet(charactersIn: "/:\\").union(.controlCharacters)).joined(separator: "-").trimmingCharacters(in: .whitespacesAndNewlines)
        
        return folder.appendingPathComponent(safeName.isEmpty ? "玩偶" : safeName).appendingPathExtension(device.fileExtension)
    }
    
    static func importFigure(_ source: URL, device: EmulatedDevice) throws -> URL {
        let folder = try directory(device: device).resolvingSymlinksInPath()
        let resolved = source.resolvingSymlinksInPath()
        
        if resolved.path.hasPrefix(folder.path + "/") { return resolved }
        
        let destination = try newFile(device: device, name: source.deletingPathExtension().lastPathComponent)
        
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }
}
