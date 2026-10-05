import SwiftUI

struct IconButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: TypeScale.body, weight: .semibold))
                .foregroundStyle(Theme.gold)
                .frame(width: Metrics.iconButton, height: Metrics.iconButton)
                .background(Circle().fill(Theme.raise))
        }
        .buttonStyle(.plain)
    }
}

struct SearchField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.placeholder)
            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(Theme.placeholder))
                .foregroundStyle(Theme.text)
                .tint(Theme.gold)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
        .font(Theme.body)
        .padding(.horizontal, Spacing.m)
        .frame(height: Metrics.searchHeight)
        .background(RoundedRectangle(cornerRadius: Radius.search, style: .continuous).fill(Theme.card))
    }
}

struct GoldCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.name)
            .foregroundStyle(Theme.goldInk)
            .padding(.horizontal, Spacing.xl)
            .frame(height: Metrics.inputControl)
            .background(Capsule().fill(Theme.gold))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(title.uppercased()).font(Theme.label).foregroundStyle(Theme.text3)
                .padding(.leading, Spacing.l)
            VStack(alignment: .leading, spacing: Spacing.m) { content }
                .padding(Spacing.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Theme.card))
        }
    }
}

struct ValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title).font(Theme.body).foregroundStyle(Theme.text)
            Spacer(minLength: Spacing.s)
            Text(value).font(Theme.preview).foregroundStyle(Theme.text2).lineLimit(1)
        }
    }
}
