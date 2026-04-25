import WidgetKit
import SwiftUI
import ActivityKit

// ── Data model ────────────────────────────────────────────────────────────

struct WidgetContact: Codable, Identifiable {
    var id: String { phone }
    let name: String
    let phone: String
    let initials: String
    let photoBase64: String?
}

// ── Timeline provider ─────────────────────────────────────────────────────

struct ContactsEntry: TimelineEntry {
    let date: Date
    let contacts: [WidgetContact]
}

struct ContactsProvider: TimelineProvider {
    func placeholder(in context: Context) -> ContactsEntry {
        ContactsEntry(date: Date(), contacts: [
            WidgetContact(name: "ישראל ישראלי", phone: "0500000001", initials: "יי", photoBase64: nil),
            WidgetContact(name: "שרה כהן",       phone: "0520000002", initials: "שכ", photoBase64: nil),
            WidgetContact(name: "דוד לוי",        phone: "0540000003", initials: "דל", photoBase64: nil),
            WidgetContact(name: "מיכל ברק",       phone: "0530000004", initials: "מב", photoBase64: nil),
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

// ── Helpers ───────────────────────────────────────────────────────────────

/// Strips all non-digit characters so tel: URLs work reliably.
private func dialURL(_ phone: String) -> URL {
    let digits = phone.filter { $0.isNumber || $0 == "+" }
    return URL(string: "tel:\(digits)") ?? URL(string: "tel:")!
}

private func firstName(_ name: String) -> String {
    name.split(separator: " ").first.map(String.init) ?? name
}

// ── Contact avatar (photo or initials) ────────────────────────────────────

struct ContactAvatar: View {
    let contact: WidgetContact
    let size: CGFloat
    let fontSize: CGFloat

    private var uiImage: UIImage? {
        guard let b64 = contact.photoBase64,
              let data = Data(base64Encoded: b64) else { return nil }
        return UIImage(data: data)
    }

    var body: some View {
        ZStack {
            if let img = uiImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1.5))
            } else {
                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: size, height: size)
                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1.5))
                Text(contact.initials)
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
}

// ── Single contact cell ───────────────────────────────────────────────────

struct ContactItemView: View {
    let contact: WidgetContact
    let avatarSize: CGFloat
    let fontSize: CGFloat

    var body: some View {
        Link(destination: dialURL(contact.phone)) {
            VStack(spacing: 5) {
                ContactAvatar(contact: contact, size: avatarSize, fontSize: avatarSize * 0.33)
                Text(firstName(contact.name))
                    .font(.system(size: fontSize, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: avatarSize + 8)
            }
        }
        .buttonStyle(.plain)
    }
}

// ── Main widget body ──────────────────────────────────────────────────────

struct ContactsWidgetView: View {
    var entry: ContactsEntry
    @Environment(\.widgetFamily) var family

    private var maxContacts: Int {
        switch family {
        case .systemSmall:  return 4
        case .systemMedium: return 4
        default:            return 8
        }
    }

    private var columns: Int {
        switch family {
        case .systemSmall:  return 2
        default:            return 4
        }
    }

    private var avatarSize: CGFloat {
        switch family {
        case .systemSmall:  return 52
        default:            return 48
        }
    }

    private var nameFontSize: CGFloat {
        family == .systemSmall ? 10 : 10
    }

    var body: some View {
        ZStack {
            // App-branded gradient background
            LinearGradient(
                colors: [Color(hex: 0x6C63FF), Color(hex: 0x4834D4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if entry.contacts.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "person.2.circle.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                    Text("פתח כדי להוסיף אנשי קשר")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                }
                .widgetURL(URL(string: "mycontacts://open"))
            } else {
                VStack(alignment: .trailing, spacing: 6) {
                    // Header
                    HStack {
                        Spacer()
                        Text("★ My Contacts")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                            .environment(\.layoutDirection, .leftToRight)
                    }

                    // Contact grid — RTL order so first contact is top-right
                    let shown = Array(entry.contacts.prefix(maxContacts))
                    let cols = columns
                    let rows = (shown.count + cols - 1) / cols

                    VStack(spacing: 10) {
                        ForEach(0..<rows, id: \.self) { row in
                            HStack(spacing: family == .systemSmall ? 8 : 10) {
                                ForEach(0..<cols, id: \.self) { col in
                                    let idx = row * cols + col
                                    if idx < shown.count {
                                        ContactItemView(
                                            contact: shown[idx],
                                            avatarSize: avatarSize,
                                            fontSize: nameFontSize
                                        )
                                        .frame(maxWidth: .infinity)
                                    } else {
                                        Spacer().frame(maxWidth: .infinity)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .environment(\.layoutDirection, .rightToLeft)
            }
        }
    }
}

// ── Lock-screen accessory views (unchanged) ───────────────────────────────

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
                Link(destination: dialURL(contact.phone)) {
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

// ── Widget entry point ─────────────────────────────────────────────────────

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
// MARK: - Emergency Widget (unchanged)
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

struct EmergencyWidgetView: View {
    var entry: EmergencyEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if let contact = entry.contact {
            let callURL = dialURL(contact.phone)
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
                LinearGradient(
                    colors: [Color(hex: 0xE53935), Color(hex: 0xB71C1C)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 60, height: 60)
                        Image(systemName: "sos")
                            .font(.system(size: 30, weight: .black))
                            .foregroundColor(.white)
                    }
                    Text(contact.name)
                        .font(.system(size: family == .systemSmall ? 13 : 16,
                                      weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
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
