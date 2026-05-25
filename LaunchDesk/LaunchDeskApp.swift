import SwiftUI

@main
struct LaunchDeskApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // 占位：真正的窗口由 AppDelegate 管理（全屏覆盖式）
        Settings {
            EmptyView()
        }
    }
}
