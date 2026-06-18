import SwiftUI

@main
struct FinderInOneApp: App {
    var body: some Scene {
        WindowGroup {
            WorkspaceView()
                .frame(minWidth: 900, minHeight: 600)
        }
    }
}
