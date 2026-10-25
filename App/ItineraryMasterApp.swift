import SwiftUI
import ItineraryCore

@main
struct ItineraryMasterApp: App {
    var body: some Scene {
        WindowGroup {
            Text("ItineraryMaster \(RouteScheduler.totalNights([ScheduleInput(nights: 3)])) nights")
        }
    }
}
