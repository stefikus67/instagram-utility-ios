import SwiftUI

/// Search and profiles arrive in milestone 6 (spec §8).
struct FindPeopleView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Find people").font(Theme.largeTitle).foregroundStyle(Theme.text)
            Text("Search, profiles and following arrive in a later build.")
                .font(Theme.preview)
                .foregroundStyle(Theme.text2)
            Spacer()
        }
        .padding(.horizontal, Spacing.screenEdge)
        .padding(.top, Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
