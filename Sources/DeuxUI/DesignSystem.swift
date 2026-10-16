import SwiftUI
import DeuxCore

// Select the established property wrapper even on SDKs that also declare a State macro.
typealias ViewState<Value> = SwiftUI.State<Value>

enum DeuxStyle {
    static let canvas = Color(red: 0.97, green: 0.96, blue: 0.93)
    static let paper = Color(red: 1.00, green: 0.995, blue: 0.98)
    static let forest = Color(red: 0.16, green: 0.29, blue: 0.23)
    static let sage = Color(red: 0.86, green: 0.90, blue: 0.83)
    static let apricot = Color(red: 0.98, green: 0.79, blue: 0.62)
    static let ink = Color(red: 0.16, green: 0.22, blue: 0.19)
    static let secondary = Color(red: 0.38, green: 0.43, blue: 0.39)
    static let line = Color(red: 0.87, green: 0.88, blue: 0.83)
    static let rust = Color(red: 0.61, green: 0.27, blue: 0.16)

    static func title(_ size: CGFloat = 34) -> Font {
        let style: Font.TextStyle = size >= 34 ? .largeTitle : size >= 28 ? .title : size >= 25 ? .title2 : .title3
        return .system(style, design: .serif)
    }

    static func date(_ date: Date, weekday: Bool = false) -> String {
        let style = Date.FormatStyle(date: .abbreviated, time: .omitted).locale(Locale(identifier: "fr_FR"))
        if weekday {
            return date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "fr_FR")))
        }
        return date.formatted(style)
    }

    static func duration(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        let remainder = minutes % 60
        return remainder == 0 ? "\(minutes / 60) h" : "\(minutes / 60) h \(remainder)"
    }
}

struct PaperCard<Content: View>: View {
    var color: Color = DeuxStyle.paper
    let content: Content

    init(color: Color = DeuxStyle.paper, @ViewBuilder content: () -> Content) {
        self.color = color
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 26)
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
            .foregroundStyle(.white)
            .background(DeuxStyle.forest.opacity(configuration.isPressed ? 0.82 : 1), in: RoundedRectangle(cornerRadius: 18))
    }
}

struct SectionHeading: View {
    let title: String
    var detail: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title).font(DeuxStyle.title(25)).foregroundStyle(DeuxStyle.ink)
            Spacer(minLength: 0)
            if let detail { Text(detail).font(.caption.weight(.medium)).foregroundStyle(DeuxStyle.secondary) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

struct Eyebrow: View {
    let text: String
    var color: Color = DeuxStyle.secondary

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(2)
            .foregroundStyle(color)
    }
}

struct FilterPill: View {
    let title: String
    let selected: Bool
    var symbol: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol { Image(systemName: symbol) }
                Text(title).lineLimit(1)
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .foregroundStyle(selected ? .white : DeuxStyle.forest)
            .background(selected ? DeuxStyle.forest : DeuxStyle.paper, in: Capsule())
            .overlay(Capsule().strokeBorder(selected ? .clear : DeuxStyle.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct PersonAvatar: View {
    let name: String
    var second = false
    var size: CGFloat = 42

    var body: some View {
        Text(String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased())
            .font(.system(size: size * 0.4, weight: .semibold, design: .serif))
            .foregroundStyle(DeuxStyle.forest)
            .frame(width: size, height: size)
            .background(second ? DeuxStyle.apricot : DeuxStyle.sage, in: Circle())
            .accessibilityHidden(true)
    }
}

struct CategoryIcon: View {
    let category: TaskCategory

    var body: some View {
        Image(systemName: category.symbolName)
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(DeuxStyle.forest)
            .frame(width: 44, height: 44)
            .background(category == .meals || category == .groceries ? DeuxStyle.apricot.opacity(0.50) : DeuxStyle.sage.opacity(0.65), in: RoundedRectangle(cornerRadius: 14))
            .accessibilityHidden(true)
    }
}

struct EmptyState: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(DeuxStyle.forest)
                .frame(width: 74, height: 74)
                .background(DeuxStyle.sage.opacity(0.65), in: Circle())
                .accessibilityHidden(true)
            Text(title).font(DeuxStyle.title(25)).foregroundStyle(DeuxStyle.ink)
            Text(message).font(.subheadline).foregroundStyle(DeuxStyle.secondary).multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .background(DeuxStyle.paper, in: RoundedRectangle(cornerRadius: 24))
    }
}

/// A small illustration made entirely from native shapes: no downloaded artwork.
struct HouseIllustration: View {
    var onDark = false

    var body: some View {
        ZStack {
            Circle().fill(DeuxStyle.apricot).frame(width: 58, height: 58).offset(x: 48, y: -41)
            Ellipse().fill(onDark ? Color.white.opacity(0.10) : DeuxStyle.sage.opacity(0.65))
                .frame(width: 155, height: 28).offset(y: 65)
            RoundedRectangle(cornerRadius: 9)
                .fill(onDark ? DeuxStyle.sage : DeuxStyle.paper)
                .frame(width: 110, height: 91).offset(y: 12)
            RoofShape().fill(onDark ? DeuxStyle.paper : DeuxStyle.forest)
                .frame(width: 139, height: 65).offset(y: -47)
            RoundedRectangle(cornerRadius: 13)
                .fill(DeuxStyle.forest).frame(width: 26, height: 47).offset(x: 23, y: 35)
            RoundedRectangle(cornerRadius: 4)
                .fill(DeuxStyle.apricot).frame(width: 25, height: 27).offset(x: -23, y: 12)
            Rectangle().fill(DeuxStyle.forest.opacity(0.65)).frame(width: 2, height: 27).offset(x: -23, y: 12)
            Rectangle().fill(DeuxStyle.forest.opacity(0.65)).frame(width: 25, height: 2).offset(x: -23, y: 12)
            Image(systemName: "leaf.fill").font(.system(size: 36)).rotationEffect(.degrees(-25))
                .foregroundStyle(onDark ? DeuxStyle.apricot : DeuxStyle.forest.opacity(0.65)).offset(x: -66, y: 43)
            Image(systemName: "heart.fill").font(.system(size: 13)).foregroundStyle(DeuxStyle.apricot).offset(x: 23, y: 28)
        }
        .frame(width: 184, height: 170)
        .accessibilityHidden(true)
    }
}

private struct RoofShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

extension View {
    @ViewBuilder func screenChrome() -> some View {
        #if os(iOS)
        toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }

    @ViewBuilder func inlineNavigationTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    @ViewBuilder func comfortableSheet() -> some View {
        #if os(iOS)
        presentationDetents([.large]).presentationDragIndicator(.visible)
        #else
        frame(minWidth: 480, idealWidth: 540, minHeight: 580, idealHeight: 740)
        #endif
    }
}
