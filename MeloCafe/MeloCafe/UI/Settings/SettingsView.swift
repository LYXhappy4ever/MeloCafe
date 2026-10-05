//
//  SettingsView.swift
//  MeloCafe
//
//  Created by Stossy11 on 7/4/2026.
//


import SwiftUI
import UniformTypeIdentifiers

extension CemuConfigWrapper {
    func cast<T>(_ value: Any) -> T? {
        value as? T
    }
}

extension Binding {
    func map<U>(
        get: @escaping (Value) -> U,
        set: @escaping (U) -> Value
    ) -> Binding<U> {
        Binding<U>(
            get: { get(self.wrappedValue) },
            set: { self.wrappedValue = set($0) }
        )
    }
}

struct NavigationStack<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        if #available(iOS 16, *) {
            SwiftUI.NavigationStack(root: content)
        } else {
            NavigationView(content: content)
                .navigationViewStyle(.stack)
        }
    }
}

struct AppIconPosition: Identifiable {
    var id: String { creator }
    var creator: String
    var icons: [AppIcon]
}

struct AppIcon: Identifiable {
    var id: String
    var name: String
    var def: Bool = false
}


struct SettingsView: View {
    @ObservedObject private var controllerManager: ControllerManager = .shared
    @StateObject private var configManager: ConfigManager = .shared
    @EnvironmentObject private var gameManager: GamesManager
    
    @AppStorage("cardType") var cardTypeRawValue: String = CardType.list.rawValue
    var cardType: Binding<CardType> {
        .init {
            CardType(rawValue: cardTypeRawValue) ?? .card
        } set: { type in
            cardTypeRawValue = type.rawValue
        }
    }
    
    @AppStorage("breakpoint") var stikDebugbreakpoint = false
    
    @AppStorage("showSwapButton") var showSwapButton: Bool = true
    @AppStorage("screenLayout") private var screenLayout = ScreenLayout.initialValue
    
    @State private var showingEmulatedDevices = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if checkAppEntitlement("get-task-allow") {
                        Picker("CPU 模式", selection: configManager.interpreter) {
                            ForEach(CPUMode.allCases, id: \.self) {
                                Text($0.string)
                            }
                        }
                        .pickerStyle(.menu)
                    } else {
                        Picker("CPU 模式", selection: .constant(CPUMode.interpreter)) {
                            ForEach(CPUMode.allCases, id: \.self) {
                                Text($0.string)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(true)
                    }
                } header: {
                    Text("CPU")
                }
                
                Section("应用") {
                    NavigationLink("更换应用图标") {
                        AppIconSwitcher()
                    }
                    
                    Picker("游戏库视图", selection: cardType) {
                        ForEach(CardType.allCases, id: \.self) {
                            Text($0.displayName)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                
                Section("通用") {
                    Picker("主机语言", selection: configManager.consoleLanguage) {
                        ForEach(ConsoleLanguage.allCases, id: \.self) {
                            Text($0.string)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    
                    HStack {
                        Text("屏幕布局")
                        
                        Button {
                            AppAlerts.showSyncAlert(title: "屏幕布局", message: screenLayout.description)
                        } label: {
                            Image(systemName: "info.circle")
                        }
                        .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Picker("", selection: $screenLayout) {
                            ForEach(ScreenLayout.allCases, id: \.self) { layout in
                                Text(layout.string).tag(layout)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    if screenLayout == .singleScreen {
                        Toggle("显示切换按钮（电视 ↔ GamePad）", isOn: $showSwapButton)
                    }
                    
                    Toggle("防止屏幕自动锁定", isOn: configManager.disableScreensaver)
                    Toggle("播放启动音效", isOn: configManager.playBootSound)
                }
                
                Section("账户") {
                    NavigationLink {
                        AccountSettingsView()
                    } label: {
                        HStack {
                            Text("账户设置")
                            Spacer()
                            Text(configManager.activeAccount?.displayName ?? "未选择账户")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section("控制器") {
                    ForEach(controllerManager.controllers) { entry in
                        ControllerRow(entry: entry)
                            .contextMenu {
                                ForEach(ControllerType.allCases) { type in
                                    if !type.name.isEmpty {
                                        Button {
                                            controllerManager.setControllerType(id: entry.id, to: type)
                                        } label: {
                                            if entry.controllerType == type {
                                                Label(type.name, systemImage: "checkmark")
                                            } else {
                                                Text(type.name)
                                            }
                                        }
                                        .disabled(!controllerManager.canSelectType(type, for: entry.id))
                                    }
                                }
                            }
                    }
                    .onMove { source, destination in
                        controllerManager.move(from: source, to: destination)
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { controllerManager.controllers[$0].id }
                        for id in ids { controllerManager.remove(id: id) }
                    }
                    
                    let cont = controllerManager.missingControllers()
                    
                    if !cont.isEmpty {
                        Menu {
                            ForEach(cont) { entry in
                                Button {
                                    controllerManager.addFromAll(id: entry.id)
                                } label: {
                                    Text(entry.name)
                                }
                                .disabled(!controllerManager.canAdd(id: entry.id))
                            }
                        } label: {
                            Label("控制器", systemImage: "chevron.down")
                        }
                    }
                    
                }
                .environment(\.editMode, .constant(.active))
                
                Section("图形") {
                    Picker("渲染器", selection: configManager.renderer) {
                        ForEach(Renderer.allCases, id: \.self) {
                            if !$0.string.isEmpty {
                                Text($0.string)
                            }
                        }
                    }
                    
                    Toggle("垂直同步", isOn: configManager.vsync)
                    Toggle("GX2 绘制完成同步", isOn: configManager.gx2DrawDoneSync)
                    Toggle("上下翻转画面", isOn: configManager.renderUpsideDown)
                    Toggle("异步编译着色器", isOn: configManager.asyncCompile)
                    Toggle("着色器缓存", isOn: configManager.precompiledShaders)
                    
                    Picker("放大滤镜", selection: configManager.upscaleFilter) {
                        ForEach(UpscalingFilter.allCases, id: \.self) {
                            Text($0.string)
                        }
                    }
                    
                    Picker("缩小滤镜", selection: configManager.downscaleFilter) {
                        ForEach(UpscalingFilter.allCases, id: \.self) {
                            Text($0.string)
                        }
                    }
                    
                    Picker("全屏缩放", selection: configManager.fullscreenScaling) {
                        ForEach(FullscreenScaling.allCases, id: \.self) {
                            Text($0.string)
                        }
                    }
                    
                    if configManager.renderer.wrappedValue == .vulkan {
                        Toggle("精确同步屏障", isOn: configManager.vkAccurateBarriers)
                    }
                    
                    if configManager.renderer.wrappedValue == .metal {
                        Toggle("强制使用网格着色器", isOn: configManager.forceMeshShaders)
                        Toggle("帧缓冲读取", isOn: configManager.framebufferFetch)
                    }
                    
                    Toggle("覆盖应用伽马设置", isOn: configManager.overrideAppGammaPreference)
                    
                    if configManager.overrideAppGammaPreference.wrappedValue {
                        VStack(alignment: .leading) {
                            HStack {
                                Text("覆盖伽马值")
                                Spacer()
                                Text(String(format: "%.2f", configManager.overrideGammaValue.wrappedValue))
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: configManager.overrideGammaValue, in: 1.0...3.0, step: 0.05)
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("显示伽马值")
                            Spacer()
                            Text(String(format: "%.2f", configManager.userDisplayGamma.wrappedValue))
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: configManager.userDisplayGamma, in: 1.0...3.0, step: 0.05)
                    }
                    
                    
                    NavigationLink("所有图形包") {
                        GraphicPacksView()
                    }
                }
                
                Section("音频") {
                    Toggle("电视音频", isOn: configManager.tvAudioEnabled)
                    Toggle("GamePad 音频", isOn: configManager.padAudioEnabled)
                    
                    Picker("电视声道", selection: configManager.tvChannels) {
                        ForEach(AudioChannels.allCases, id: \.self) {
                            Text($0.string)
                        }
                    }
                    
                    Picker("GamePad 声道", selection: configManager.padChannels) {
                        ForEach(AudioChannels.allCases, id: \.self) {
                            Text($0.string)
                        }
                    }
                    
                    Picker("输入声道", selection: configManager.inputChannels) {
                        ForEach(AudioChannels.allCases, id: \.self) {
                            Text($0.string)
                        }
                    }
                    
                    Toggle("麦克风", isOn: configManager.microphoneEnabled)
                    
                    VStack(alignment: .leading) {
                        Text("电视音量：\(Int(configManager.tvVolume.wrappedValue))%")
                        Slider(value: configManager.tvVolume, in: 0...100, step: 1)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("GamePad 音量：\(Int(configManager.padVolume.wrappedValue))%")
                        Slider(value: configManager.padVolume, in: 0...100, step: 1)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("输入音量：\(Int(configManager.inputVolume.wrappedValue))%")
                        Slider(value: configManager.inputVolume, in: 0...100, step: 1)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("传送门音量：\(Int(configManager.portalVolume.wrappedValue))%")
                        Slider(value: configManager.portalVolume, in: 0...100, step: 1)
                    }
                }
                
                Section("屏幕信息") {
                    Picker("位置", selection: configManager.overlayPosition) {
                        ForEach(ScreenPosition.allCases, id: \.self) {
                            Text($0.string)
                        }
                    }
                    
                    TextField("文字颜色", text: configManager.overlayTextColorHex)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    VStack(alignment: .leading) {
                        Text("文字缩放：\(Int(configManager.overlayTextScale.wrappedValue))%")
                        Slider(value: configManager.overlayTextScale, in: 50...200, step: 25)
                    }
                    
                    Toggle("帧率", isOn: configManager.overlayFPS)
                    Toggle("CPU 模式", isOn: configManager.overlayCPUMode)
                    Toggle("绘制调用次数", isOn: configManager.overlayDrawcalls)
                    Toggle("CPU 使用率", isOn: configManager.overlayCPUUsage)
                    Toggle("各 CPU 核心使用率", isOn: configManager.overlayCPUPerCoreUsage)
                    Toggle("内存使用量", isOn: configManager.overlayRAMUsage)
                    Toggle("显存使用量", isOn: configManager.overlayVRAMUsage)
                    Toggle("调试信息", isOn: configManager.overlayDebug)
                }
                
                Section("通知") {
                    Picker("位置", selection: configManager.notificationPosition) {
                        ForEach(ScreenPosition.allCases, id: \.self) {
                            Text($0.string)
                        }
                    }
                    
                    TextField("文字颜色", text: configManager.notificationTextColorHex)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    VStack(alignment: .leading) {
                        Text("文字缩放：\(Int(configManager.notificationTextScale.wrappedValue))%")
                        Slider(value: configManager.notificationTextScale, in: 50...200, step: 25)
                    }
                    
                    Toggle("控制器配置", isOn: configManager.notificationControllerProfiles)
                    Toggle("电量不足", isOn: configManager.notificationControllerBattery)
                    Toggle("着色器编译", isOn: configManager.notificationShaderCompiling)
                    Toggle("好友", isOn: configManager.notificationFriends)
                }
                
                Section("输入服务") {
                    Toggle("禁用体感输入", isOn: configManager.disableMotion)
                    
                    //TextField("DSU 主机", text: configManager.dsuHost)
                    //    .textInputAutocapitalization(.never)
                    //    .autocorrectionDisabled()
                    
                    //TextField("DSU 端口", text: configManager.dsuPortString)
                    //    .keyboardType(.numberPad)
                }
                
                Section("模拟外设") {
                    Toggle("Skylanders 传送门", isOn: configManager.emulateSkylanderPortal)
                    Toggle("迪士尼无限底座", isOn: configManager.emulateInfinityBase)
                    Toggle("乐高次元玩具底座", isOn: configManager.emulateDimensionsToypad)
                    Button {
                        showingEmulatedDevices = true
                    } label: {
                        Label("管理玩偶", systemImage: "externaldrive.connected.to.line.below")
                    }
                    .sheet(isPresented: $showingEmulatedDevices) {
                        EmulatedDevicesView()
                    }
                }
                
                Section("加载游戏") {
                    Button("从文件夹加载") {
                        FileImporterManager.shared.importFiles(
                            types: [.folder],
                            allowMultiple: false,
                            stopAccessingSecurityScopedResources: false
                        ) { result in
                            handleImportResult(result)
                        }
                    }
                    
                    Button("从文件加载") {
                        FileImporterManager.shared.importFiles(
                            types: [.item],
                            allowMultiple: false,
                            stopAccessingSecurityScopedResources: false
                        ) { result in
                            handleImportResult(result)
                        }
                    }
                }
            }
            .navigationTitle("设置") // iOS 15 seems to expect a navigation title, so we'll put this here. -stossy11
        }
    }
    
    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            _ = url.startAccessingSecurityScopedResource()
            gameManager.loadGame(url.path, true)
        case .failure(let error):
            print("Failed to import: \(error)")
        }
    }
}

private struct ControllerRow: View {
    let entry: ControllerEntry

    var body: some View {
        HStack {
            Image(systemName: entry.isVirtual ? "iphone" : "gamecontroller.fill")
                .foregroundStyle(entry.isVirtual ? .blue : .primary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.body)
                Text(entry.controllerType.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
