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

/// A username text field plus a gold save button. `onSave` returns false when the text is not a valid Instagram
/// username, which shows an inline message.
struct UsernameEntry: View {
    let buttonTitle: String
    let onSave: (String) -> Bool
    @State private var draft = ""
    @State private var invalid = false

    init(buttonTitle: String, onSave: @escaping (String) -> Bool) {
        self.buttonTitle = buttonTitle
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            TextField("username", text: $draft, prompt: Text("username").foregroundColor(Theme.placeholder))
                .font(Theme.body)
                .foregroundStyle(Theme.text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, Spacing.l)
                .frame(height: Metrics.inputControl)
                .background(RoundedRectangle(cornerRadius: Radius.field, style: .continuous).fill(Theme.card))
                .onChange(of: draft) { _ in invalid = false }
            Button(buttonTitle) { invalid = !onSave(draft) }
                .buttonStyle(GoldCapsuleButtonStyle())
            if invalid {
                Text("That isn't a valid Instagram username.")
                    .font(Theme.label)
                    .foregroundStyle(Theme.text3)
            }
        }
    }
}
