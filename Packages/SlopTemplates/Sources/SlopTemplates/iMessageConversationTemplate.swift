import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct iMessageContact: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Name") var name: String = ""
    @Field("Avatar") var avatar: TemplateImage = TemplateImage("")
}

@SlopData
public struct iMessageMessage: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Sender Index") var senderIndex: Int = 0
    @Field("Content") var content: String = ""
    @Field("Image") var image: TemplateImage = TemplateImage("")
    @Field("Timestamp") var timestamp: Date = .now
}

@SlopData
public struct iMessageConversationData {
    @SlopKit.Section("Conversation")
    @Field("Contact Name") var contactName: String = "Alex"
    @Field("Contact Avatar") var contactAvatar: TemplateImage = TemplateImage("")

    @SlopKit.Section("Participants")
    @Field("Contacts") var contacts: [iMessageContact] = iMessageConversationData.defaultContacts

    @SlopKit.Section("Messages")
    @Field("Messages") var messages: [iMessageMessage] = iMessageConversationData.defaultMessages

    @SlopKit.Section("Settings")
    @Field("Show Timestamps") var showTimestamps: Bool = false
}

extension iMessageConversationData {
    static var defaultContacts: [iMessageContact] {
        func contact(_ name: String) -> iMessageContact {
            var c = iMessageContact()
            c.name = name
            return c
        }
        return [
            contact("You"),
            contact("Alex")
        ]
    }

    static var defaultMessages: [iMessageMessage] {
        func message(_ senderIndex: Int, _ content: String) -> iMessageMessage {
            var m = iMessageMessage()
            m.senderIndex = senderIndex
            m.content = content
            return m
        }

        return [
            message(1, "Hey! Are you free this weekend?"),
            message(0, "Yeah! What did you have in mind?"),
            message(1, "Thinking we could check out that new coffee place"),
            message(0, "Sounds perfect! Saturday morning?"),
            message(1, "Perfect. See you at 10!"),
            message(0, "Can't wait! ☕️")
        ]
    }
}

// MARK: - Template

@SlopTemplate(
    id: "com.hitslop.templates.imessage-conversation",
    name: "iMessage Conversation",
    description: "Realistic iPhone message bubbles for screenshots and mockups.",
    version: "1.0.0",
    width: 393, height: 852,
    minWidth: 320, minHeight: 500,
    shape: .roundedRect(radius: 55),
    theme: "minimal-mono",
    alwaysOnTop: true,
    categories: ["media"]
)
struct iMessageConversationView: View {
    @TemplateData var data: iMessageConversationData
    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget

    private let iosBlue = Color(red: 0x00/255, green: 0x7A/255, blue: 0xFF/255)
    private let iosGray = Color(red: 0xE5/255, green: 0xE5/255, blue: 0xEA/255)
    private let iosBackground = Color(red: 0xF2/255, green: 0xF2/255, blue: 0xF7/255)
    private let navBarBackground = Color(red: 0xF9/255, green: 0xF9/255, blue: 0xF9/255)

    var body: some View {
        VStack(spacing: 0) {
            // Navigation bar
            navigationBar

            // Message list - messages start at top
            messageListView
                .slopExportableFrame(maxHeight: .infinity)
                .background(iosBackground)

            // Input bar
            inputBar
        }
        .slopExportableFrame(maxWidth: .infinity, maxHeight: .infinity)
        .background(iosBackground)
    }

    @ViewBuilder
    private var messageListView: some View {
        if renderTarget == .interactive {
            ScrollView {
                messageContent
            }
        } else {
            messageContent
        }
    }

    private var messageContent: some View {
        VStack(spacing: 8) {
            ForEach($data.messages) { $message in
                MessageRow(
                    message: $message,
                    showTimestamp: data.showTimestamps,
                    iosBlue: iosBlue,
                    iosGray: iosGray
                )
            }

            SlopInteractiveOnly {
                AddItemButton("Add Message") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        data.messages.append(iMessageMessage())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 12)
        .slopExportableFrame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var navigationBar: some View {
        VStack(spacing: 0) {
            // Status bar
            iOSStatusBar(time: "9:41", style: .dark)

            // Nav bar with contact info
            iOSNavigationBar(
                title: $data.contactName,
                avatar: $data.contactAvatar,
                showBackButton: true,
                backButtonText: "Messages",
                accentColor: iosBlue,
                backgroundColor: navBarBackground,
                trailingIcons: ["phone.fill", "video.fill"]
            )
        }
    }

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.gray.opacity(0.2))

            HStack(spacing: 8) {
                Button(action: {}) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Color.gray.opacity(0.6))
                }
                .buttonStyle(.plain)

                HStack {
                    Text("iMessage")
                        .foregroundStyle(Color.gray.opacity(0.4))
                }
                .font(.system(size: 15))
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 17)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 17)
                                .strokeBorder(Color.gray.opacity(0.2), lineWidth: 0.5)
                        )
                )

                Image(systemName: "mic.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.gray.opacity(0.6))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(Color.white)
        }
    }
}

// MARK: - Message Row

struct MessageRow: View {
    @Binding var message: iMessageMessage
    let showTimestamp: Bool
    let iosBlue: Color
    let iosGray: Color

    var isFromUser: Bool {
        message.senderIndex == 0
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !isFromUser {
                Spacer(minLength: 60)
            }

            VStack(alignment: isFromUser ? .trailing : .leading, spacing: 4) {
                if !message.image.path.isEmpty {
                    SlopImage(image: $message.image, placeholder: "Drop image")
                        .frame(width: 220, height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }

                if !message.content.isEmpty {
                    iOSChatBubble(
                        content: $message.content,
                        isFromUser: isFromUser,
                        userColor: iosBlue,
                        otherColor: iosGray
                    )
                }

                if showTimestamp {
                    Text(formatTime(message.timestamp))
                        .font(.system(size: 11))
                        .foregroundStyle(Color.gray.opacity(0.6))
                }
            }

            if isFromUser {
                Spacer(minLength: 60)
            }

            SlopInteractiveOnly {
                RemoveButton {
                    // Note: We can't use withAnimation here since we're inside a binding
                    // The parent will handle the removal
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}



