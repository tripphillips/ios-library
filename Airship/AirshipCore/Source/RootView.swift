/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

struct RootView<Content: View>: View {

    #if !os(tvOS) && !os(watchOS)
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    @State private var currentOrientation: Orientation = RootView.resolveOrientation()

    @State private var isForeground: Bool = true
    @State private var isVisible: Bool = false

    @ObservedObject var thomasEnvironment: ThomasEnvironment

    let layout: AirshipLayout
    let content: (Orientation, WindowSize) -> Content

    init(
        thomasEnvironment: ThomasEnvironment,
        layout: AirshipLayout,
        @ViewBuilder content: @escaping (Orientation, WindowSize) -> Content
    ) {
        self.thomasEnvironment = thomasEnvironment
        self.layout = layout
        self.content = content
        self.isForeground = AppStateTracker.shared.isForegrounded
    }

    @ViewBuilder
    var body: some View {
        content(currentOrientation, resolveWindowSize())
        .environmentObject(thomasEnvironment)
        .environmentObject(thomasEnvironment.defaultFormState)
        .environmentObject(thomasEnvironment.defaultViewState)
        .environmentObject(thomasEnvironment.defaultPagerState)
        .environment(\.orientation, currentOrientation)
        .environment(\.windowSize, resolveWindowSize())
        .environment(\.isVisible, isVisible)
        .onReceive(NotificationCenter.default.publisher(for: AppStateTracker.didTransitionToForeground)) { (_) in
            self.isForeground = true
            self.thomasEnvironment.onVisbilityChanged(isVisible: self.isVisible, isForegrounded: self.isForeground)
        }
        .onReceive(NotificationCenter.default.publisher(for: AppStateTracker.didTransitionToBackground)) { (_) in
            self.isForeground = false
            self.thomasEnvironment.onVisbilityChanged(isVisible: self.isVisible, isForegrounded: self.isForeground)
        }
        .onAppear {
            self.currentOrientation = RootView.resolveOrientation()
            self.isVisible = true
            self.thomasEnvironment.onVisbilityChanged(isVisible: self.isVisible, isForegrounded: self.isForeground)
        }
        .onDisappear {
            self.isVisible = false
            self.thomasEnvironment.onVisbilityChanged(isVisible: self.isVisible, isForegrounded: self.isForeground)
        }
        #if os(iOS)
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIDevice.orientationDidChangeNotification
            )
        ) { _ in
            self.currentOrientation = RootView.resolveOrientation()
        }
        #endif
    }

    /// Uses the vertical and horizontal class size to determine small, medium, large window size:
    /// - large: regular x regular = large
    /// - medium: regular x compact or compact x regular
    /// - small: compact x compact
    func resolveWindowSize() -> WindowSize {
        #if os(tvOS) || os(watchOS)
        return .large
        #else
        switch (verticalSizeClass, horizontalSizeClass) {
        case (.regular, .regular):
            return .large
        case (.compact, .compact):
            return .small
        default:
            return .medium
        }
        #endif
    }

    static func resolveOrientation() -> Orientation {
        #if os(tvOS) || os(watchOS)
        return .landscape
        #else
        let scene = try? AirshipSceneManager.shared.lastActiveScene

        if let scene = scene {
            if scene.interfaceOrientation.isLandscape {
                return .landscape
            } else if scene.interfaceOrientation.isPortrait {
                return .portrait
            }
        }
        return .portrait
        #endif
    }
}
