import SwiftUI

/// A realistic iMessage-style chat bubble component.
///
/// Displays a message bubble with customizable sender direction, colors, and tail position.
/// The bubble expands to fit text content and wraps SlopTextField for editability.
///
/// ```swift
/// iOSChatBubble(
///     content: $message.content,
///     isFromUser: message.senderIndex == 0,
///     userColor: iosBlue,
///     otherColor: iosGray
/// )
/// ```
public struct iOSChatBubble: View {
    @Binding var content: String
    var isFromUser: Bool
    var userColor: Color = Color(red: 0x00/255, green: 0x7A/255, blue: 0xFF/255)
    var otherColor: Color = Color(red: 0xE5/255, green: 0xE5/255, blue: 0xEA/255)
    var maxWidth: CGFloat = 280

    public init(
        content: Binding<String>,
        isFromUser: Bool,
        userColor: Color = Color(red: 0x00/255, green: 0x7A/255, blue: 0xFF/255),
        otherColor: Color = Color(red: 0xE5/255, green: 0xE5/255, blue: 0xEA/255),
        maxWidth: CGFloat = 280
    ) {
        self._content = content
        self.isFromUser = isFromUser
        self.userColor = userColor
        self.otherColor = otherColor
        self.maxWidth = maxWidth
    }

    public var body: some View {
        SlopTextField("Message", text: $content)
            .font(.system(size: 15))
            .foregroundStyle(isFromUser ? .white : .black)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                BubbleShape(isFromUser: isFromUser)
                    .fill(isFromUser ? userColor : otherColor)
            )
            .frame(maxWidth: maxWidth, alignment: isFromUser ? .trailing : .leading)
    }
}

/// The bubble shape with a tail indicating sender direction.
///
/// This shape draws a rounded rectangle with a small tail pointing
/// towards the sender (right for user, left for other).
public struct BubbleShape: Shape {
    let isFromUser: Bool

    public init(isFromUser: Bool) {
        self.isFromUser = isFromUser
    }

    public func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 18
        let tailSize: CGFloat = 6

        var path = Path()

        if isFromUser {
            // Right-aligned bubble (user)
            path.move(to: CGPoint(x: rect.maxX - tailSize, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX - tailSize, y: rect.maxY - tailSize))

            path.addLine(to: CGPoint(x: rect.maxX - tailSize, y: rect.minY + radius))
            path.addArc(center: CGPoint(x: rect.maxX - tailSize - radius, y: rect.minY + radius),
                        radius: radius,
                        startAngle: .degrees(0),
                        endAngle: .degrees(-90),
                        clockwise: true)

            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.minY))
            path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
                        radius: radius,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(-180),
                        clockwise: true)

            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - radius))
            path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
                        radius: radius,
                        startAngle: .degrees(180),
                        endAngle: .degrees(90),
                        clockwise: true)

            path.addLine(to: CGPoint(x: rect.maxX - tailSize, y: rect.maxY))
        } else {
            // Left-aligned bubble (contact)
            path.move(to: CGPoint(x: rect.minX + tailSize, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + tailSize, y: rect.maxY - tailSize))

            path.addLine(to: CGPoint(x: rect.minX + tailSize, y: rect.minY + radius))
            path.addArc(center: CGPoint(x: rect.minX + tailSize + radius, y: rect.minY + radius),
                        radius: radius,
                        startAngle: .degrees(180),
                        endAngle: .degrees(-90),
                        clockwise: false)

            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
                        radius: radius,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(0),
                        clockwise: false)

            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
            path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
                        radius: radius,
                        startAngle: .degrees(0),
                        endAngle: .degrees(90),
                        clockwise: false)

            path.addLine(to: CGPoint(x: rect.minX + tailSize, y: rect.maxY))
        }

        path.closeSubpath()
        return path
    }
}
