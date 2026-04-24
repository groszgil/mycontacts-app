import WidgetKit
import SwiftUI

@main
struct ContactsWidgetBundle: WidgetBundle {
    var body: some Widget {
        ContactsWidget()
        EmergencyWidget()
    }
}
