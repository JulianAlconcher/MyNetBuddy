import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = NetworkViewModel()

    var body: some View {
        MenuBarContentView(viewModel: viewModel)
            .frame(width: 360)
    }
}

#Preview {
    ContentView()
}
