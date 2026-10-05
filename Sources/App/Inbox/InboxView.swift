import SwiftUI

struct InboxView: View {
    @EnvironmentObject private var inbox: InboxStore
    @EnvironmentObject private var session: InstagramSession
    @State private var query = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                SearchField(text: $query, placeholder: "Search chats")
                    .padding(.horizontal, Spacing.screenEdge)
                    .padding(.top, Spacing.m)
                StoriesRow(items: inbox.showsSampleData ? SampleStories.items : [])
                    .padding(.top, Spacing.l)
                    .padding(.bottom, Spacing.m)
                threads
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .refreshable { await inbox.reload() }
        .task { await inbox.reload() }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("Messages").font(Theme.largeTitle).foregroundStyle(Theme.text)
            Spacer()
            // New message opens web chat until native chat lands (milestone 2).
            IconButton(systemImage: "square.and.pencil") { session.openWebChat() }
        }
        .padding(.horizontal, Spacing.screenEdge)
        .padding(.top, Spacing.s)
    }

    @ViewBuilder private var threads: some View {
        let all = inbox.snapshot?.threads ?? []
        let shown = InboxSearch.filter(all, query: query)
        if all.isEmpty {
            emptyState
        } else if shown.isEmpty {
            Text("No chats match “\(query)”")
                .font(Theme.preview).foregroundStyle(Theme.text2)
                .frame(maxWidth: .infinity)
                .padding(.top, Spacing.xxl)
        } else {
            let now = Date()
            LazyVStack(spacing: Metrics.cardGap) {
                ForEach(shown) { thread in
                    Button { session.openWebChat() } label: {
                        ChatCard(thread: thread,
                                 timestamp: RelativeTimestamp.string(for: thread.lastActivity, now: now,
                                                                     calendar: .current, locale: .current))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.screenEdge)
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.m) {
            Text("No chats here yet").font(Theme.name).foregroundStyle(Theme.text)
            Text("The native inbox connects in the next build. Until then, use web chat — or turn on the sample inbox in You to preview the design.")
                .font(Theme.preview)
                .foregroundStyle(Theme.text2)
                .multilineTextAlignment(.center)
            Button("Open web chat") { session.openWebChat() }
                .buttonStyle(GoldCapsuleButtonStyle())
                .padding(.top, Spacing.s)
        }
        .padding(Spacing.xxl)
        .frame(maxWidth: .infinity)
    }
}
