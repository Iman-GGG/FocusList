import SwiftUI

enum Theme {
    static let background = Color(hex: "171818")
    static let sidebar = Color(hex: "202121")
    static let panel = Color(hex: "1C1D1D")
    static let elevated = Color(hex: "272828")
    static let line = Color.white.opacity(0.075)
    static let primary = Color(hex: "F1F1EE")
    static let secondary = Color(hex: "9B9C99")
    static let accent = Color(hex: "E8FF59")
    static let purple = Color(hex: "8B7CFF")
}

extension Color {
    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xff) / 255
        let g = Double((value >> 8) & 0xff) / 255
        let b = Double(value & 0xff) / 255
        self.init(red: r, green: g, blue: b)
    }
}

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 28, height: 28)
            .background(configuration.isPressed ? Color.white.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
    }
}

struct Pill: View {
    let icon: String
    let text: String
    var color: Color = Theme.secondary
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 10, weight: .semibold))
            Text(text).font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}
