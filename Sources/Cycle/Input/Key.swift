import Carbon.HIToolbox
import CoreGraphics

/// Virtual key codes the switcher responds to.
enum Key {
	static let tab = CGKeyCode(kVK_Tab)
	static let escape = CGKeyCode(kVK_Escape)
	static let returnKey = CGKeyCode(kVK_Return)
	static let keypadEnter = CGKeyCode(kVK_ANSI_KeypadEnter)
	static let left = CGKeyCode(kVK_LeftArrow)
	static let right = CGKeyCode(kVK_RightArrow)
	static let up = CGKeyCode(kVK_UpArrow)
	static let down = CGKeyCode(kVK_DownArrow)
	static let grave = CGKeyCode(kVK_ANSI_Grave)
	static let delete = CGKeyCode(kVK_Delete)
	static let space = CGKeyCode(kVK_Space)
	/// 1 to 9 on the main row, in order.
	static let digits: [CGKeyCode] = [
		kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7,
		kVK_ANSI_8, kVK_ANSI_9,
	].map { CGKeyCode($0) }
}
