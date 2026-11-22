import ApplicationServices

extension AXUIElement {
	func attribute<T>(_ name: String) -> T? {
		var value: CFTypeRef?
		guard AXUIElementCopyAttributeValue(self, name as CFString, &value) == .success else {
			return nil
		}
		return value as? T
	}

	func pointAttribute(_ name: String) -> CGPoint? {
		var value: CFTypeRef?
		guard AXUIElementCopyAttributeValue(self, name as CFString, &value) == .success,
			let value, CFGetTypeID(value) == AXValueGetTypeID()
		else { return nil }
		var point = CGPoint.zero
		return AXValueGetValue(value as! AXValue, .cgPoint, &point) ? point : nil
	}

	func sizeAttribute(_ name: String) -> CGSize? {
		var value: CFTypeRef?
		guard AXUIElementCopyAttributeValue(self, name as CFString, &value) == .success,
			let value, CFGetTypeID(value) == AXValueGetTypeID()
		else { return nil }
		var size = CGSize.zero
		return AXValueGetValue(value as! AXValue, .cgSize, &size) ? size : nil
	}
}
