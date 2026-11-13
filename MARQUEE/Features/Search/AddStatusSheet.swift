import SwiftUI

/// Picks the status when adding with +. One tap adds and closes.
struct AddStatusSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let result: SearchResult
    let onPick: (EntryStatus) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(spacing: Space.s) {
                PosterCard(item: PosterContent(result), showsRating: false, showsStatus: false)
                    .frame(width: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Eyebrow(String(localized: "Add to library"))
                    Text(result.name)
                        .font(.cardTitle(theme.titleDesign))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(2)
                }
            }
            VStack(spacing: Space.xs) {
                ForEach(statuses, id: \.self) { status in
                    Button {
                        dismiss()
                        onPick(status)
                    } label: {
                        HStack(spacing: Space.s) {
                            IconBubble(symbol: status.symbol)
                            Text(status.label(for: result.kind))
                                .font(.body.weight(.semibold))
                                .foregroundStyle(theme.textPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, Space.s)
                        .frame(minHeight: 52)
                        .background(theme.surface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityIdentifier("addSheet.\(status.rawValue)")
                }
            }
        }
        .padding(Space.l)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(theme.surface1.ignoresSafeArea())
    }

    private var statuses: [EntryStatus] { [.wantTo, .inProgress, .finished] }
}
