import UIKit

/// Meaningful haptics only (§5.6). Never on ordinary taps.
enum Haptics {
    /// Mirrors the haptics setting; updated at launch and when it changes.
    static var enabled = true

    /// Half-stars while rating, segment changes, reordering.
    static func selection() {
        guard enabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// Adding to the library.
    static func light() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Finishing a title, hitting a goal.
    static func success() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Confirming something destructive.
    static func warning() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
