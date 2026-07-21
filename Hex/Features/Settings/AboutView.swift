import ComposableArchitecture
import Inject
import SwiftUI

struct AboutView: View {
    @Environment(\.openWindow) private var openWindow
    @ObserveInjection var inject
    @Bindable var store: StoreOf<SettingsFeature>
    @State private var showingChangelog = false

    var body: some View {
        Form {
            Section {
                HStack {
                    Label("Version", systemImage: "info.circle")
                    Spacer()
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown")
                    Button("Check Upstream") {
                        openWindow(id: UpstreamCheckWindow.id)
                    }
                    .buttonStyle(.bordered)
                }
                HStack {
                    Label("Changelog", systemImage: "doc.text")
                    Spacer()
                    Button("Show Changelog") {
                        showingChangelog.toggle()
                    }
                    .buttonStyle(.bordered)
                    .sheet(isPresented: $showingChangelog, onDismiss: {
                        showingChangelog = false
                    }) {
                        ChangelogView()
                    }
                }
                HStack {
                    Label("Hex fork source", systemImage: "apple.terminal.on.rectangle")
                    Spacer()
                    Link("Visit GitHub", destination: URL(string: "https://github.com/robin-liquidium/Hex/")!)
                }
                
                HStack {
                    Label("Support the developer", systemImage: "heart")
                    Spacer()
                    Link("Become a Sponsor", destination: URL(string: "https://github.com/sponsors/kitlangton")!)
                }
            }
        }
        .formStyle(.grouped)
        .enableInjection()
    }
}
