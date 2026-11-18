import AppKit

/// Window thumbnails via `CGSHWCaptureWindowList`, one window per call, as DockDoor's
/// `PreviewCaptureScheduler` does. Results are cached by window id so a session can paint
/// the last image immediately while a fresh one is captured.
final class ThumbnailCache: @unchecked Sendable {
	struct Captured {
		let image: NSImage
		/// Average colour, used to tint the card.
		let tint: NSColor
	}

	private var cache: [CGWindowID: Captured] = [:]
	private let lock = NSLock()
	private let queue = DispatchQueue(
		label: "Cycle.capture", qos: .userInteractive, attributes: .concurrent)

	func cached(_ id: CGWindowID) -> Captured? {
		lock.withLock { cache[id] }
	}

	/// Captures each id off the main thread; `completion` runs on main per image.
	func capture(
		_ ids: [CGWindowID], best: Bool, completion: @escaping (CGWindowID, Captured) -> Void
	) {
		for id in ids {
			queue.async { [weak self] in
				guard let image = Self.captureOne(id, best: best) else { return }
				let captured = Captured(
					image: NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height)),
					tint: Self.averageColor(image))
				self?.lock.withLock { self?.cache[id] = captured }
				DispatchQueue.main.async { completion(id, captured) }
			}
		}
	}

	func prune(keeping ids: Set<CGWindowID>) {
		lock.withLock { cache = cache.filter { ids.contains($0.key) } }
	}

	private static func captureOne(_ id: CGWindowID, best: Bool) -> CGImage? {
		var wid = id
		guard
			let array = CGSHWCaptureWindowList(
				CGSMainConnectionID(), &wid, 1, best ? CaptureFlags.best : CaptureFlags.nominal)?
				.takeRetainedValue() as? [CGImage],
			let image = array.first, image.width > 1, image.height > 1
		else { return nil }
		return image
	}

	/// A saturated version of the window's dominant colour: samples a 16×16 downscale,
	/// weights each pixel by its saturation so white and black areas count little, then
	/// clamps saturation and brightness so the card reads as tinted glass.
	private static func averageColor(_ image: CGImage) -> NSColor {
		let side = 16
		var pixels = [UInt8](repeating: 0, count: side * side * 4)
		guard let context = CGContext(
			data: &pixels, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
			space: CGColorSpaceCreateDeviceRGB(),
			bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
		else { return .gray }
		context.interpolationQuality = .medium
		context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
		var r = 0.0, g = 0.0, b = 0.0, total = 0.0
		for i in stride(from: 0, to: pixels.count, by: 4) {
			let pr = Double(pixels[i]) / 255, pg = Double(pixels[i + 1]) / 255, pb = Double(pixels[i + 2]) / 255
			let maxC = max(pr, pg, pb), minC = min(pr, pg, pb)
			let saturation = maxC == 0 ? 0 : (maxC - minC) / maxC
			let weight = 0.02 + saturation * saturation * maxC
			r += pr * weight; g += pg * weight; b += pb * weight; total += weight
		}
		let base = NSColor(srgbRed: r / total, green: g / total, blue: b / total, alpha: 1)
		var hue: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0, alpha: CGFloat = 0
		base.usingColorSpace(.sRGB)?.getHue(&hue, saturation: &sat, brightness: &bri, alpha: &alpha)
		return NSColor(hue: hue, saturation: min(max(sat, 0.35), 0.75), brightness: 0.55, alpha: 1)
	}
}
