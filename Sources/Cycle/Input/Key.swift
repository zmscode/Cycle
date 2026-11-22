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
}
