import SwiftUI

public struct ContentView: View {
    @State private var selectedTab = 0
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            TranscriptView()
                .tabItem {
                    Label("Transcript", systemImage: "doc.text")
                }
                .tag(0)
            
            ThumbnailView()
                .tabItem {
                    Label("Thumbnail", systemImage: "photo")
                }
                .tag(1)
        }
        .frame(minWidth: 900, minHeight: 700)
    }
    
    public init() {}
}
