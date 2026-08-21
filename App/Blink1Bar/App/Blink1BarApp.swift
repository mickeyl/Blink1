import SwiftUI

@main
struct Blink1BarApp: App {

    @State private var model: AppModel

    init() {
        let model = AppModel()
        _model = State(initialValue: model)
        // MenuBarExtra builds its content lazily — the first time the menu is opened. Waiting for
        // that to start driving the device would leave the LED dark until someone clicked.
        model.start()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environment(model)
        } label: {
            MenuBarLabel(color: model.currentOutput.indicatorColor, isConnected: model.isConnected)
        }
        .menuBarExtraStyle(.window)
    }
}
