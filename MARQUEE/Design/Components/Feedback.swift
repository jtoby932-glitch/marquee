import Observation
import SwiftUI

/// One toast at a time at the bottom of the screen, gone after 5 s, with an
/// optional Undo and poster thumbnail.
@MainActor @Observable
final class ToastCenter {
    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let message: String
        var poster: PosterContent?
        var undoTitle: String?

        static func == (a: Toast, b: Toast) -> Bool { a.id == b.id }
    }

    private(set) var current: Toast?
    @ObservationIgnored private var undoAction: (() -> Void)?
    @ObservationIgnored private var dismissTask: Task<Void, Never>?

    func show(_ message: String, poster: PosterContent? = nil, undo: (() -> Void)? = nil) {
        dismissTask?.cancel()
        undoAction = undo
        current = Toast(message: message, poster: poster, undoTitle: undo == nil ? nil : String(localized: "Undo"))
        AppLog.info(.ui, "Toast shown")
        let id = current?.id
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled, let self, self.current?.id == id else { return }
            self.dismiss()
        }
    }

    func undo() {
        let action = undoAction
        dismiss()
        action?()
    }

    func dismiss() {
        dismissTask?.cancel()
        undoAction = nil
        current = nil
    }
}

struct ToastView: View {
    @Environment(\.theme) private var theme
    let toast: ToastCenter.Toast
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: Space.s) {
            if let poster = toast.poster {
                PosterCard(item: poster, showsRating: false, showsStatus: false)
                    .frame(width: 28)
                    .accessibilityHidden(true)
            }
            Text(toast.message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            if let undo = toast.undoTitle {
                Button(undo, action: onUndo)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(theme.accent)
                    .frame(minWidth: Touch.minimum, minHeight: Touch.minimum)
                    .accessibilityIdentifier("toast.undo")
            }
        }
        .padding(.horizontal, Space.m)
        .padding(.vertical, Space.xs)
        .background(theme.surface3, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(theme.strokeStrong, lineWidth: 1))
        .floatingShadow()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("toast")
    }
}

/// One helpful sentence and one action (§5.8), with an original illustration.
struct EmptyStateView: View {
    @Environment(\.theme) private var theme
    let illustration: Illustration.Kind
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?
    var identifier = "empty"

    var body: some View {
        VStack(spacing: Space.l) {
            Illustration(kind: illustration)
                .frame(width: 132, height: 104)
            Text(message)
                .font(.body)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 300)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.primary)
                    .accessibilityIdentifier("\(identifier).action")
            }
        }
        .padding(.vertical, Space.xxxl)
        .padding(.horizontal, Space.margin)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }
}

/// An inline error: what happened and what to do next, with a retry.
struct InlineError: View {
    @Environment(\.theme) private var theme
    let message: UserFacingError.Message
    var retry: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: Space.s) {
            IconBubble(symbol: "exclamationmark.triangle", tint: theme.warning)
            VStack(alignment: .leading, spacing: 2) {
                Text(message.title).font(.subheadline.weight(.semibold)).foregroundStyle(theme.textPrimary)
                Text(message.detail).font(.subheadline).foregroundStyle(theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let retry {
                Button(String(localized: "Try again"), action: retry)
                    .buttonStyle(.ghost)
                    .accessibilityIdentifier("error.retry")
            }
        }
        .padding(Space.card)
        .card()
        .accessibilityElement(children: .contain)
    }
}

/// A small, calm offline indicator.
struct OfflineBanner: View {
    @Environment(\.theme) private var theme
    var message = String(localized: "You're offline")

    var body: some View {
        Label(message, systemImage: "wifi.slash")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, Space.s)
            .padding(.vertical, 6)
            .background(theme.surface2, in: Capsule())
            .overlay(Capsule().strokeBorder(theme.stroke, lineWidth: 1))
            .accessibilityIdentifier("offline.banner")
    }
}

/// Skeleton shapes shown while loading. Shimmer is static when motion is reduced.
struct SkeletonPoster: View {
    @Environment(\.theme) private var theme
    var body: some View {
        RoundedRectangle(cornerRadius: theme.posterRadius, style: .continuous)
            .fill(theme.surface2)
            .aspectRatio(AspectRatio.poster, contentMode: .fit)
            .shimmer()
            .accessibilityHidden(true)
    }
}

struct SkeletonRow: View {
    @Environment(\.theme) private var theme
    var body: some View {
        HStack(spacing: Space.s) {
            RoundedRectangle(cornerRadius: 6, style: .continuous).fill(theme.surface2).frame(width: 52, height: 78)
            VStack(alignment: .leading, spacing: Space.xs) {
                Capsule().fill(theme.surface2).frame(width: 180, height: 12)
                Capsule().fill(theme.surface2).frame(width: 110, height: 10)
            }
            Spacer()
        }
        .shimmer()
        .accessibilityHidden(true)
    }
}
