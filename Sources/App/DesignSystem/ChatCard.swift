import SwiftUI

struct ChatCard: View {
    let thread: ThreadSummary
    let timestamp: String

    var body: some View {
        HStack(spacing: Spacing.m) {
            Avatar(url: thread.avatarURL, size: Metrics.chatAvatar)
            VStack(alignment: .leading, spacing: 0) {
                Text(thread.title)
                    .font(Theme.name)
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text(thread.lastMessagePreview)
                    .font(thread.isUnread ? Theme.previewUnread : Theme.preview)
                    .foregroundStyle(thread.isUnread ? Theme.text : Theme.text2)
                    .lineLimit(1)
            }
            Spacer(minLength: Spacing.s)
            VStack(alignment: .trailing, spacing: Spacing.s) {
                Text(timestamp).font(Theme.time).foregroundStyle(Theme.text3)
                if thread.isUnread {
                    Circle().fill(Theme.gold).frame(width: Metrics.unreadDot, height: Metrics.unreadDot)
                }
            }
        }
        .padding(.leading, Metrics.chatAvatarInset)
        .padding(.trailing, Spacing.l)
        .frame(height: Metrics.chatCardHeight)
        .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Theme.card))
        .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}
