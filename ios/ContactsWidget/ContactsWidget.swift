import WidgetKit
import SwiftUI
import ActivityKit

// ── Data model ────────────────────────────────────────────────────────────

struct WidgetContact: Codable, Identifiable {
    var id: String { phone }
    let name: String
    let phone: String
    let initials: String
}

// ── Timeline provider ─────────────────────────────────────────────────────

struct ContactsEntry: TimelineEntry {
    let date: Date
    let contacts: [WidgetContact]
}

struct ContactsProvider: TimelineProvider {
    func placeholder(in context: Context) -> ContactsEntry {
        ContactsEntry(date: Date(), contacts: [
            WidgetContact(name: "ישראל ישראלי", phone: "050-0000001", initials: "יי"),
            WidgetContact(name: "שרה כהן",       phone: "052-0000002", initials: "שכ"),
            WidgetContact(name: "דוד לוי",        phone: "054-0000003", initials: "דל"),
            WidgetContact(name: "מיכל ברק",       phone: "053-0000004", initials: "מב"),
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (ContactsEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ContactsEntry>) -> Void) {
        let entry = loadEntry()
        completion(Timeline(entries: [entry], policy: .never))
    }

    private func loadEntry() -> ContactsEntry {
        guard
            let defaults = UserDefaults(suiteName: "group.com.mycontacts.myContacts"),
            let json = defaults.string(forKey: "contacts_json"),
            let data = json.data(using: .utf8),
            let contacts = try? JSONDecoder().decode([WidgetContact].self, from: data)
        else {
            return ContactsEntry(date: Date(), contacts: [])
        }
        return ContactsEntry(date: Date(), contacts: Array(contacts.prefix(8)))
    }
}

// ── Views ─────────────────────────────────────────────────────────────────

struct ContactItemView: View {
    let contact: WidgetContact

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 46, height: 46)
                    .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                Text(contact.initials)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(hex: 0x6C63FF))
                    .environment(\.layoutDirection, .rightToLeft)
            }
            Text(firstName(contact.name))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(maxWidth: 56)
        }
    }

    func firstName(_ name: String) -> String {
        name.split(separator: " ").first.map(String.init) ?? name
    }
}

struct ContactsWidgetView: View {
    var entry: ContactsEntry
    @Environment(\.widgetFamily) var family

    var gridColumns: [GridItem] {
        if family == .systemSmall {
            return [GridItem(.flexible()), GridItem(.flexible())]
        }
        return [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
        ]
    }

    var body: some View {
        ZStack {
            // Purple gradient background
            LinearGradient(
                colors: [Color(hex: 0x6C63FF), Color(hex: 0x4834D4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if entry.contacts.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "person.2.circle")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundColor(.white)
                    Text("פתח כדי להוסיף אנשי קשר")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                }
                .widgetURL(URL(string: "mycontacts://open"))
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    // App title row
                    HStack(spacing: 4) {
                        Text("★ My Contacts")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                    }
                    .padding(.horizontal, 4)

                    LazyVGrid(columns: gridColumns, spacing: 10) {
                        ForEach(entry.contacts) { contact in
                            Link(destination: URL(string: "mycontacts://call/\(contact.phone.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? contact.phone)")!) {
                                ContactItemView(contact: contact)
                            }
                        }
                    }
                }
                .padding(10)
                .environment(\.layoutDirection, .rightToLeft)
            }
        }
    }
}

// ── Widget entry point ────────────────────────────────────────────────────

// ── Lock Screen accessory views ────────────────────────────────────────────

struct ContactsAccessoryCircularView: View {
    var entry: ContactsEntry
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: 0x6C63FF))
                if let first = entry.contacts.first {
                    Text(first.initials)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.primary)
                }
            }
        }
        .widgetURL(URL(string: "mycontacts://open"))
    }
}

struct ContactsAccessoryRectangularView: View {
    var entry: ContactsEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: 0x6C63FF))
                Text("אנשי קשר")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.primary)
            }
            ForEach(entry.contacts.prefix(3)) { contact in
                Link(destination: URL(string: "mycontacts://call/\(contact.phone.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? contact.phone)")!) {
                    Text("• \(contact.name)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.layoutDirection, .rightToLeft)
    }
}

struct ContactsAccessoryInlineView: View {
    var entry: ContactsEntry
    var body: some View {
        if let first = entry.contacts.first {
            Label(first.name, systemImage: "phone.fill")
        } else {
            Label("אנשי קשר", systemImage: "person.2")
        }
    }
}

struct ContactsWidget: Widget {
    let kind = "ContactsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ContactsProvider()) { entry in
            ContactsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("אנשי קשר מועדפים")
        .description("חיוג מהיר לאנשי קשר מועדפים")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

struct ContactsWidgetEntryView: View {
    var entry: ContactsEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ContactsAccessoryCircularView(entry: entry)
        case .accessoryRectangular:
            ContactsAccessoryRectangularView(entry: entry)
        case .accessoryInline:
            ContactsAccessoryInlineView(entry: entry)
        default:
            ContactsWidgetView(entry: entry)
                .containerBackground(for: .widget) {}
        }
    }
}

// ── Color extension ───────────────────────────────────────────────────────

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8)  & 0xFF) / 255.0
        let b = Double(hex         & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// ════════════════════════════════════════════════════════════════════════════
// MARK: - Emergency Widget
// ════════════════════════════════════════════════════════════════════════════

struct EmergencyContact: Codable {
    let name: String
    let phone: String
    let enabled: Bool
}

struct EmergencyEntry: TimelineEntry {
    let date: Date
    let contact: EmergencyContact?
}

struct EmergencyProvider: TimelineProvider {
    func placeholder(in context: Context) -> EmergencyEntry {
        EmergencyEntry(date: Date(),
                       contact: EmergencyContact(name: "ישראל ישראלי",
                                                 phone: "050-0000000",
                                                 enabled: true))
    }

    func getSnapshot(in context: Context, completion: @escaping (EmergencyEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EmergencyEntry>) -> Void) {
        completion(Timeline(entries: [loadEntry()], policy: .never))
    }

    private func loadEntry() -> EmergencyEntry {
        guard
            let defaults = UserDefaults(suiteName: "group.com.mycontacts.myContacts"),
            let json = defaults.string(forKey: "emergency_json"),
            let data = json.data(using: .utf8),
            let contact = try? JSONDecoder().decode(EmergencyContact.self, from: data),
            contact.enabled, !contact.phone.isEmpty
        else {
            return EmergencyEntry(date: Date(), contact: nil)
        }
        return EmergencyEntry(date: Date(), contact: contact)
    }
}

// ── Emergency views ───────────────────────────────────────────────────────

struct EmergencyWidgetView: View {
    var entry: EmergencyEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if let contact = entry.contact {
            let callURL = URL(string: "mycontacts://call/\(contact.phone.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? contact.phone)")!
            Link(destination: callURL) {
                emergencyBody(contact: contact)
            }
        } else {
            disabledBody
        }
    }

    @ViewBuilder
    func emergencyBody(contact: EmergencyContact) -> some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 2) {
                    Image(systemName: "sos")
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(.red)
                    Text(firstName(contact.name))
                        .font(.system(size: 8, weight: .semibold))
                        .lineLimit(1)
                }
            }
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: "sos")
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(.red)
                VStack(alignment: .leading, spacing: 2) {
                    Text("חירום")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.red)
                    Text(contact.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(contact.phone)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .environment(\.layoutDirection, .rightToLeft)
        default:
            ZStack {
                // Red gradient background
                LinearGradient(
                    colors: [Color(hex: 0xE53935), Color(hex: 0xB71C1C)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VStack(spacing: 10) {
                    // SOS icon
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 60, height: 60)
                        Image(systemName: "sos")
                            .font(.system(size: 30, weight: .black))
                            .foregroundColor(.white)
                    }
                    // Contact name
                    Text(contact.name)
                        .font(.system(size: family == .systemSmall ? 13 : 16,
                                      weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    // "גע לחיוג"
                    Text("גע לחיוג חירום")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding()
            }
            .environment(\.layoutDirection, .rightToLeft)
        }
    }

    var disabledBody: some View {
        VStack(spacing: 6) {
            Image(systemName: "sos")
                .font(.system(size: 28, weight: .black))
                .foregroundColor(.gray)
            Text("לא הוגדר\nאיש קשר חירום")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .widgetURL(URL(string: "mycontacts://open"))
    }

    func firstName(_ name: String) -> String {
        name.split(separator: " ").first.map(String.init) ?? name
    }
}

struct EmergencyWidget: Widget {
    let kind = "EmergencyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EmergencyProvider()) { entry in
            EmergencyWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("כפתור חירום")
        .description("חיוג מהיר לאיש קשר חירום")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
        ])
    }
}
