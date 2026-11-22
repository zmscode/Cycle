/// Capture flags recovered from DockDoor's capture routine (0x100b55508): it passes
/// 0x80900 for best quality and 0x80A00 for nominal. 0x800 ignores the global clip shape,
/// 0x100 / 0x200 pick best / nominal resolution; 0x80000 is set in both.
enum CaptureFlags {
	static let best: UInt32 = 0x80900
	static let nominal: UInt32 = 0x80A00
}
