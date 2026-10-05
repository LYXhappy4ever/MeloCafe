//
//  EmulationView.swift
//  MeloCafe
//
//  Created by Stossy11 on 9/4/2026.
//

import SwiftUI
import Melo_Controller

struct EmulationView: View {
    let cemuView: MetalView
    let cemuPadView: MetalView
    @StateObject private var controllerManager = ControllerManager.shared
    @StateObject private var controllerHandler = VirtualControllerHandler()
    @AppStorage("showSwapButton") private var showSwapButton = true
    @AppStorage("screenLayout") private var screenLayout = ScreenLayout.initialValue
    @State private var swapped = false
    @State private var showingEmulatedDevices = false
    @ObservedObject private var configManager = ConfigManager.shared
    @ObservedObject private var air = Air.shared
    @EnvironmentObject private var gameManager: GamesManager
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.scenePhase) private var scenePhase

    private var visibleScreens: [Bool] {
        if air.connected { return [false] }
        if screenLayout.showsBothScreens { return swapped ? [false, true] : [true, false] }
        return [!swapped]
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { geometry in
                let portrait = geometry.size.height >= geometry.size.width
                if screenLayout == .smallGamePadTopRight && !air.connected {
                    let padWidth = geometry.size.width * 0.25
                    let padHeight = min(padWidth * 9 / 16, geometry.size.height)
                    HStack(alignment: .top, spacing: 0) {
                        MetalViewContainer(metalView: cemuView)
                            .frame(width: geometry.size.width - padWidth,
                                   height: geometry.size.height)
                        MetalViewContainer(metalView: cemuPadView)
                            .frame(width: padWidth, height: padHeight)
                    }
                } else if portrait {
                    VStack(spacing: 0) { screens }
                } else {
                    HStack(spacing: 0) { screens }
                }
            }
            .ignoresSafeArea(.all, edges: verticalSizeClass == .regular ? .horizontal : .all)

            if controllerManager.hasVirtual() {
                ControllerView(controller: controllerHandler, isEditing: false)
            }
        }
        .overlay(alignment: .topLeading) {
            Menu {
                if showSwapButton && screenLayout == .singleScreen && !air.connected {
                    Button {
                        swapped.toggle()
                    } label: {
                        Label("切换 TV / GamePad", systemImage: "rectangle.2.swap")
                    }
                }

                Button(role: .destructive) {
                    gameManager.stopEmulation()
                } label: {
                    Label("返回 MeloCafe", systemImage: "arrow.backward.circle")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.6), in: Circle())
            }
            .accessibilityLabel("游戏菜单")
            .padding(10)
        }
        .statusBarHidden(true)
        .overlay(alignment: .topTrailing) {
            if configManager.emulateSkylanderPortal.wrappedValue ||
                configManager.emulateInfinityBase.wrappedValue ||
                configManager.emulateDimensionsToypad.wrappedValue {
                Button {
                    showingEmulatedDevices = true
                } label: {
                    Image(systemName: "externaldrive.connected.to.line.below")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.6), in: Circle())
                }
                .accessibilityLabel("模拟外设")
                .sheet(isPresented: $showingEmulatedDevices) {
                    EmulatedDevicesView()
                }
                .padding(10)
            }
        }
        .onAppear {
            updateVisibleOutputs()
            Air.play(AnyView(MetalViewContainer(metalView: cemuView)))
        }
        .onChange(of: swapped) { _ in updateVisibleOutputs() }
        .onChange(of: screenLayout) { _ in updateVisibleOutputs() }
        .onChange(of: air.connected) { _ in updateVisibleOutputs() }
        .onChange(of: scenePhase) { phase in
            handleScenePhase(phase)
        }
        .onDisappear {
            Air.stop()
            cemuPadView.cancelActiveTouches()
            CemuUIKit_SetVisibleOutputs(false, false)
        }
    }

    private var screens: some View {
        ForEach(visibleScreens, id: \.self) { main in
            MetalViewContainer(metalView: main ? cemuView : cemuPadView)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            controllerManager.virtualController.resumeMotionAfterForeground()
            cemuView.updateDrawableSize()
            cemuPadView.updateDrawableSize()
            cemuView.setNeedsDisplay()
            cemuPadView.setNeedsDisplay()
            updateVisibleOutputs()
        case .inactive, .background:
            controllerManager.virtualController.suspendMotionForBackground()
            cemuPadView.cancelActiveTouches()
            CemuUIKit_SetVisibleOutputs(false, false)
        @unknown default:
            break
        }
    }

    private func updateVisibleOutputs() {
        let both = air.connected || screenLayout.showsBothScreens

        CemuUIKit_SetVisibleOutputs(both || !swapped, both || swapped)

        if !both && !swapped { cemuPadView.cancelActiveTouches() }
    }
}

extension VirtualControllerButton {
    static var swap = Self("swap", systemName: "rectangle.2.swap", small: true)
}
