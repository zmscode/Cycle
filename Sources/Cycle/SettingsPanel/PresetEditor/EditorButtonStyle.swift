import SwiftUI

/// The editor's capsule buttons: plain, prominent (Save) or destructive (Delete).
struct EditorButtonStyle: ButtonStyle {
	enum Kind { case plain, prominent, destructive }
	var kind: Kind = .plain

	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.font(.caption.weight(.semibold))
			.foregroundStyle(kind == .destructive ? Color.red : .white)
			.padding(.horizontal, 12)
			.padding(.vertical, 5)
			.background(background, in: .capsule)
			.overlay { Capsule().strokeBorder(.white.opacity(kind == .prominent ? 0.25 : 0.12)) }
			.opacity(configuration.isPressed ? 0.75 : 1)
			.scaleEffect(configuration.isPressed ? 0.97 : 1)
			.animation(.snappy(duration: 0.12), value: configuration.isPressed)
	}

	private var background: AnyShapeStyle {
		switch kind {
		case .prominent: AnyShapeStyle(Theme.Colors.mark.gradient)
		case .plain, .destructive: AnyShapeStyle(.white.opacity(0.08))
		}
	}
}
