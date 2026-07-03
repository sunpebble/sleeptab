import SwiftUI

@main
struct SleeptabApp: App {
    @State private var pro = ProStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(pro)
                .task {
                    await pro.load()
                    await pro.listenForTransactions()
                }
        }
    }
}
