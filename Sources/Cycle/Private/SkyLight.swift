import ApplicationServices
import CoreGraphics
import Foundation

// Private window-server and accessibility SPI. DockDoor Pro 1.8.0 imports the same set
// (see docs/FINDINGS.md). CGS* and _AX* resolve through CoreGraphics / ApplicationServices
// at link time; the SLPS* calls live only in SkyLight, so they are looked up at run time.

typealias CGSConnectionID = UInt32

@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> CGSConnectionID

/// Returns an array of CGImages, one per window ID; nil when the server refuses.
@_silgen_name("CGSHWCaptureWindowList")
func CGSHWCaptureWindowList(
	_ cid: CGSConnectionID,
	_ windowList: UnsafeMutablePointer<CGWindowID>,
	_ count: UInt32,
	_ options: UInt32
) -> Unmanaged<CFArray>?

/// Spaces (as CGSSpaceIDs) that hold each window in `windows`. Mask 0x7 = all spaces.
@_silgen_name("CGSCopySpacesForWindows")
func CGSCopySpacesForWindows(_ cid: CGSConnectionID, _ mask: Int32, _ windows: CFArray)
	-> Unmanaged<CFArray>?

@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: UnsafeMutablePointer<CGWindowID>)
	-> AXError

@_silgen_name("GetProcessForPID")
func GetProcessForPID(_ pid: pid_t, _ psn: UnsafeMutablePointer<ProcessSerialNumber>) -> OSStatus

/// Capture flags recovered from DockDoor's capture routine (0x100b55508): it passes
/// 0x80900 for best quality and 0x80A00 for nominal. 0x800 ignores the global clip shape,
/// 0x100 / 0x200 pick best / nominal resolution; 0x80000 is set in both.
enum CaptureFlags {
	static let best: UInt32 = 0x80900
	static let nominal: UInt32 = 0x80A00
}

enum SkyLight {
	private static let handle = dlopen(
		"/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)

	private typealias SetFrontFn =
		@convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, CGWindowID, UInt32) -> CGError
	private typealias PostEventFn =
		@convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, UnsafeMutablePointer<UInt8>) ->
		CGError

	private static let setFront: SetFrontFn? = {
		guard let handle, let sym = dlsym(handle, "_SLPSSetFrontProcessWithOptions") else {
			return nil
		}
		return unsafeBitCast(sym, to: SetFrontFn.self)
	}()

	private static let postEvent: PostEventFn? = {
		guard let handle, let sym = dlsym(handle, "SLPSPostEventRecordTo") else { return nil }
		return unsafeBitCast(sym, to: PostEventFn.self)
	}()

	/// kCPSUserGenerated: the window server treats the switch like a click, so it follows
	/// the window to its Space.
	private static let userGenerated: UInt32 = 0x200

	/// Brings `pid` forward with `windowID` as its front window, switching Spaces if needed.
	@discardableResult
	static func setFrontProcess(pid: pid_t, windowID: CGWindowID) -> Bool {
		var psn = ProcessSerialNumber()
		guard GetProcessForPID(pid, &psn) == noErr, let setFront else { return false }
		guard setFront(&psn, windowID, userGenerated) == .success else { return false }
		makeKeyWindow(psn: &psn, windowID: windowID)
		return true
	}

	/// Posts the window-server event record that makes `windowID` key in its process.
	/// Layout as DockDoor builds it at 0x100b92fa4: a 0x100-byte record, length 0xf8 at
	/// 0x04, type 1 at 0x08, two doubles of 300000.0 (an off-screen location) at 0x20,
	/// 0x10 at 0x3a and the window id at 0x3c. DockDoor posts it once.
	private static func makeKeyWindow(psn: inout ProcessSerialNumber, windowID: CGWindowID) {
		guard let postEvent else { return }
		var bytes = [UInt8](repeating: 0, count: 0x100)
		bytes[0x04] = 0xf8
		bytes[0x08] = 0x01
		bytes[0x3a] = 0x10
		func put<T>(_ value: T, at offset: Int) {
			withUnsafeBytes(of: value) { raw in
				for (i, b) in raw.enumerated() { bytes[offset + i] = b }
			}
		}
		put(300000.0, at: 0x20)
		put(300000.0, at: 0x28)
		put(windowID, at: 0x3c)
		_ = postEvent(&psn, &bytes)
	}
}
