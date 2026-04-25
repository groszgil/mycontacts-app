import WidgetKit
import SwiftUI

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
        completion(Timeline(entries: [loadEntry()], policy: .never))
    }
    private func loadEntry() -> ContactsEntry {
        guard
            let defaults = UserDefaults(suiteName: "group.com.mycontacts.myContacts"),
            let json    = defaults.string(forKey: "contacts_json"),
            let data    = json.data(using: .utf8),
            let list    = try? JSONDecoder().decode([WidgetContact].self, from: data)
        else { return ContactsEntry(date: Date(), contacts: []) }
        return ContactsEntry(date: Date(), contacts: Array(list.prefix(8)))
    }
}

// ── Helpers ───────────────────────────────────────────────────────────────

private func callURL(_ raw: String) -> URL {
    // Keep digits and leading +; strip everything else for a valid tel: URL
    let cleaned = raw.unicodeScalars
        .filter { CharacterSet.decimalDigits.union(CharacterSet(charactersIn: "+")).contains($0) }
    let str = String(cleaned)
    return URL(string: "tel:\(str)") ?? URL(string: "mycontacts://open")!
}

private func firstName(_ name: String) -> String {
    name.split(separator: " ").first.map(String.init) ?? name
}

// ── Gradient colours matching the Flutter app ─────────────────────────────

private let gradientTop    = Color(hex: 0x6C63FF)
private let gradientBottom = Color(hex: 0x4834D4)
private let appGradient    = LinearGradient(
    colors: [gradientTop, gradientBottom],
    startPoint: .topLeading, endPoint: .bottomTrailing
)

// ── Avatar ────────────────────────────────────────────────────────────────

struct ContactAvatar: View {
    let contact: WidgetContact
    let size: CGFloat

    private var photo: UIImage? {
        guard let b64 = contact.photoBase64,
              let data = Data(base64Encoded: b64) else { return nil }
        return UIImage(data: data)
    }

    var body: some View {
        ZStack {
            if let img = photo {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(0.4), lineWidth: 1.5)
                    )
            } else {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(0.35), lineWidth: 1.5)
                    )
                Text(contact.initials)
                    .font(.system(size: size * 0.33, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
        .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
    }
}

// ── Single contact cell ───────────────────────────────────────────────────

struct ContactCell: View {
    let contact: WidgetContact
    let avatarSize: CGFloat
    let nameFontSize: CGFloat

    var body: some View {
        Link(destination: callURL(contact.phone)) {
            VStack(spacing: 5) {
                ContactAvatar(contact: contact, size: avatarSize)
                Text(firstName(contact.name))
                    .font(.system(size: nameFontSize, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: avatarSize + 6)
            }
        }
        .buttonStyle(.plain)
    }
}

// ── Main widget view ──────────────────────────────────────────────────────

struct ContactsWidgetView: View {
    var entry: ContactsEntry
    @Environment(\.widgetFamily) var family

    private var columns: Int    { family == .systemSmall ? 2 : 4 }
    private var maxItems: Int   { family == .systemSmall ? 4 : (family == .systemMedium ? 4 : 8) }
    private var avatarSize: CGFloat { family == .systemSmall ? 54 : 46 }
    private var fontSize: CGFloat   { family == .systemSmall ? 10 : 10 }
    private var hPad: CGFloat   { family == .systemSmall ? 10 : 14 }
    private var vPad: CGFloat   { family == .systemSmall ? 12 : 10 }

    var body: some View {
        if entry.contacts.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "person.2.circle.fill")
                    .font(.system(size: 42))
                    .foregroundColor(.white.opacity(0.8))
                Text("פתח כדי להוסיף אנשי קשר")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .widgetURL(URL(string: "mycontacts://open"))
        } else {
            let shown = Array(entry.contacts.prefix(maxItems))
            let cols  = columns
            let rows  = (shown.count + cols - 1) / cols

            VStack(spacing: family == .systemSmall ? 10 : 8) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: family == .systemSmall ? 6 : 8) {
                        ForEach(0..<cols, id: \.self) { col in
                            let idx = row * cols + col
                            if idx < shown.count {
                                ContactCell(
                                    contact: shown[idx],
                                    avatarSize: avatarSize,
                                    nameFontSize: fontSize
                                )
                                .frame(maxWidth: .infinity)
                            } else {
                                Color.clear
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, hPad)
            .padding(.vertical, vPad)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .environment(\.layoutDirection, .rightToLeft)
        }
    }
}

// ── Widget entry view (sets gradient as containerBackground = no white frame) ─

struct ContactsWidgetEntryView: View {
    var entry: ContactsEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:    ContactsAccessoryCircularView(entry: entry)
        case .accessoryRectangular: ContactsAccessoryRectangularView(entry: entry)
        case .accessoryInline:      ContactsAccessoryInlineView(entry: entry)
        default:
            ContactsWidgetView(entry: entry)
                // Gradient fills the entire widget including corners — no white frame
                .containerBackground(appGradient, for: .widget)
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
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryCircular, .accessoryRectangular, .accessoryInline,
        ])
    }
}

// ── Lock-screen accessory views ───────────────────────────────────────────

struct ContactsAccessoryCircularView: View {
    var entry: ContactsEntry
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(gradientTop)
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
            ForEach(entry.contacts.prefix(3)) { contact in
                Link(destination: callURL(contact.phone)) {
                    HStack(spacing: 5) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 9))
                            .foregroundColor(gradientTop)
                        Text(contact.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
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

// ── Color extension ───────────────────────────────────────────────────────

extension Color {
    init(hex: UInt32) {
        self.init(
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >>  8) & 0xFF) / 255,
            blue:  Double( hex        & 0xFF) / 255
        )
    }
}

// ════════════════════════════════════════════════════════════════════════════
// MARK: - Emergency Widget
// ════════════════════════════════════════════════════════════════════════════

struct EmergencyContact: Codable {
    let name: String; let phone: String; let enabled: Bool
}
struct EmergencyEntry: TimelineEntry {
    let date: Date; let contact: EmergencyContact?
}

struct EmergencyProvider: TimelineProvider {
    func placeholder(in context: Context) -> EmergencyEntry {
        EmergencyEntry(date: Date(),
            contact: EmergencyContact(name: "ישראל ישראלי", phone: "050-0000000", enabled: true))
    }
    func getSnapshot(in context: Context, completion: @escaping (EmergencyEntry) -> Void) { completion(loadEntry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<EmergencyEntry>) -> Void) {
        completion(Timeline(entries: [loadEntry()], policy: .never))
    }
    private func loadEntry() -> EmergencyEntry {
        guard let defaults = UserDefaults(suiteName: "group.com.mycontacts.myContacts"),
              let json = defaults.string(forKey: "emergency_json"),
              let data = json.data(using: .utf8),
              let c    = try? JSONDecoder().decode(EmergencyContact.self, from: data),
              c.enabled, !c.phone.isEmpty
        else { return EmergencyEntry(date: Date(), contact: nil) }
        return EmergencyEntry(date: Date(), contact: c)
    }
}

struct EmergencyWidgetView: View {
    var entry: EmergencyEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if let c = entry.contact {
            Link(destination: callURL(c.phone)) { emergencyContent(c) }
        } else { disabledView }
    }

    @ViewBuilder
    func emergencyContent(_ c: EmergencyContact) -> some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 2) {
                    Image(systemName: "sos").font(.system(size: 18, weight: .black)).foregroundColor(.red)
                    Text(firstName(c.name)).font(.system(size: 8, weight: .semibold)).lineLimit(1)
                }
            }
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: "sos").font(.system(size: 20, weight: .black)).foregroundColor(.red)
                VStack(alignment: .leading, spacing: 2) {
                    Text("חירום").font(.system(size: 11, weight: .bold)).foregroundColor(.red)
                    Text(c.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    Text(c.phone).font(.system(size: 10)).foregroundColor(.secondary)
                }
                Spacer()
            }.environment(\.layoutDirection, .rightToLeft)
        default:
            ZStack {
                LinearGradient(colors: [Color(hex: 0xE53935), Color(hex: 0xB71C1C)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                VStack(spacing: 10) {
                    ZStack {
                        Circle().fill(Color.white.opacity(0.2)).frame(width: 60, height: 60)
                        Image(systemName: "sos").font(.system(size: 30, weight: .black)).foregroundColor(.white)
                    }
                    Text(c.name)
                        .font(.system(size: family == .systemSmall ? 13 : 16, weight: .bold))
                        .foregroundColor(.white).lineLimit(1)
                    Text("גע לחיוג חירום")
                        .font(.system(size: 10, weight: .medium)).foregroundColor(.white.opacity(0.8))
                }
                .padding()
            }.environment(\.layoutDirection, .rightToLeft)
        }
    }

    var disabledView: some View {
        VStack(spacing: 6) {
            Image(systemName: "sos").font(.system(size: 28, weight: .black)).foregroundColor(.gray)
            Text("לא הוגדר\nאיש קשר חירום")
                .font(.caption2).foregroundColor(.secondary).multilineTextAlignment(.center)
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
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}
