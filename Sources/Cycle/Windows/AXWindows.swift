import AppKit
import ApplicationServices

/// AX side of enumeration.
enum AXWindows {
	struct Entry {
		let id: CGWindowID
		let element: AXUIElement
		let title: String?
		let frame: CGRect
		let isMinimized: Bool
		/// A dialog or panel rather than a document window.
		let isDialog: Bool
	}

	static func collect(pids: [pid_t]) -> [pid_t: [Entry]] {
		var results = [[Entry]](repeating: [], count: pids.count)
		results.withUnsafeMutableBufferPointer { buffer in
			let base = buffer.baseAddress!
			DispatchQueue.concurrentPerform(iterations: pids.count) { i in
				base[i] = windows(of: pids[i])
			}
		}
		return Dictionary(uniqueKeysWithValues: zip(pids, results))
	}

	static func windows(of pid: pid_t) -> [Entry] {
		let app = AXUIElementCreateApplication(pid)
		AXUIElementSetMessagingTimeout(app, 0.15)
		guard let list: [AXUIElement] = app.attribute(kAXWindowsAttribute) else { return [] }
		return list.compactMap { element in
			var wid: CGWindowID = 0
			guard _AXUIElementGetWindow(element, &wid) == .success, wid != 0 else { return nil }
			let subrole: String? = element.attribute(kAXSubroleAttribute)
			guard subrole == kAXStandardWindowSubrole || subrole == kAXDialogSubrole else {
				return nil
			}
			let position: CGPoint = element.pointAttribute(kAXPositionAttribute) ?? .zero
			let size: CGSize = element.sizeAttribute(kAXSizeAttribute) ?? .zero
			return Entry(
				id: wid, element: element,
				title: element.attribute(kAXTitleAttribute),
				frame: CGRect(origin: position, size: size),
				isMinimized: element.attribute(kAXMinimizedAttribute) ?? false,
				isDialog: subrole == kAXDialogSubrole
			)
		}
	}
}
