import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = NetworkViewModel()

    var body: some View {
        MenuBarContentView(viewModel: viewModel)
            .frame(width: 360)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
