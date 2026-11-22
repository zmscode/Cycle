import AppKit

/// Window thumbnails via `CGSHWCaptureWindowList`, one window per call, as DockDoor's
/// `PreviewCaptureScheduler` does. Results are cached by window id so a session can paint
/// the last image immediately while a fresh one is captured.
final class ThumbnailCache: @unchecked Sendable {
	struct Captured {
		let image: NSImage
		/// Average colour, used to tint the card.
		let tint: NSColor
		let capturedAt: Date
	}

	private var cache: [CGWindowID: Captured] = [:]
	private let lock = NSLock()
	/// At most three captures at once, so a burst of sessions can't flood the window
	/// server; cancelling a session drops whatever hasn't started.
	private let queue: OperationQueue = {
		let queue = OperationQueue()
		queue.name = "Cycle.capture"
		queue.maxConcurrentOperationCount = 3
		queue.qualityOfService = .userInteractive
		return queue
	}()

	func cached(_ id: CGWindowID) -> Captured? {
		lock.withLock { cache[id] }
	}

	/// Captures each id that has no image newer than `maxAge`, off the main thread;
	/// `completion` runs on main per image.
	func capture(
		_ ids: [CGWindowID], best: Bool, maxAge: TimeInterval,
		completion: @escaping (CGWindowID, Captured) -> Void
	) {
		let now = Date()
		let stale = ids.filter { id in
			guard let cached = cached(id) else { return true }
			return now.timeIntervalSince(cached.capturedAt) > maxAge
		}
		for id in stale {
			queue.addOperation { [weak self] in
				guard let raw = Self.captureOne(id, best: best) else { return }
				// DockDoor's rule (0x100b54e90 / 0x100b54f58): a capture with no visible
				// pixels failed, and one that's mostly see-through (often a window still
				// drawing) doesn't replace the image already shown.
				let coverage = Self.coverage(raw)
				if coverage == 0 { return }
				if coverage < 0.5, self?.cached(id) != nil { return }
				let image = Self.flattened(raw)
				let captured = Captured(
					image: NSImage(
						cgImage: image, size: NSSize(width: image.width, height: image.height)),
					tint: Self.averageColor(image),
					capturedAt: Date())
				self?.lock.withLock { self?.cache[id] = captured }
				DispatchQueue.main.async { completion(id, captured) }
			}
		}
	}

	/// For `Cycle --dump`: what the capture pipeline makes of one window.
	static func inspect(_ id: CGWindowID) -> String {
		guard let raw = captureOne(id, best: false) else { return "no capture" }
		let flat = flattened(raw)
		let backdrop =
			backdropColor(raw).flatMap { color in
				color.components.map {
					$0.prefix(3).map { String(format: "%.2f", $0) }.joined(separator: " ")
				}
			} ?? "none"
		return String(
			format: "%dx%d coverage %.2f flattened %@ fill [%@] mean %.2f",
			raw.width, raw.height, coverage(raw), flat === raw ? "no" : "yes", backdrop,
			meanBrightness(flat))
	}

	private static func meanBrightness(_ image: CGImage) -> Double {
		let side = 32
		var pixels = [UInt8](repeating: 0, count: side * side * 4)
		guard
			let context = CGContext(
				data: &pixels, width: side, height: side, bitsPerComponent: 8,
				bytesPerRow: side * 4,
				space: CGColorSpaceCreateDeviceRGB(),
				bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
		else { return 0 }
		context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
		var sum = 0.0
		for i in stride(from: 0, to: pixels.count, by: 4) {
			sum += Double(pixels[i]) + Double(pixels[i + 1]) + Double(pixels[i + 2])
		}
		return sum / Double(side * side * 3) / 255
	}

	/// Drops captures queued for a session that has ended.
	func cancelPending() {
		queue.cancelAllOperations()
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

	/// The share of a capture's pixels that aren't fully transparent, sampled on a grid
	/// (DockDoor's 0x100b5adec does the same count over the raw bytes).
	private static func coverage(_ image: CGImage) -> Double {
		switch image.alphaInfo {
		case .none, .noneSkipFirst, .noneSkipLast: return 1
		default: break
		}
		let side = 32
		var pixels = [UInt8](repeating: 0, count: side * side * 4)
		guard
			let context = CGContext(
				data: &pixels, width: side, height: side, bitsPerComponent: 8,
				bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
				bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
		else { return 1 }
		context.interpolationQuality = .none
		context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
		var visible = 0
		for i in stride(from: 3, to: pixels.count, by: 4) where pixels[i] > 0 { visible += 1 }
		return Double(visible) / Double(side * side)
	}

	/// Translucent windows (see-through terminals, vibrancy sidebars) capture with alpha,
	/// and the switcher's own glass would show through them. This puts the capture on a
	/// solid fill in the average colour of the window's opaque pixels — dark for a dark
	/// terminal, light for a light sidebar — close to the frosted backdrop it has on
	/// screen. Images with (almost) no transparency are returned unchanged.
	private static func flattened(_ image: CGImage) -> CGImage {
		switch image.alphaInfo {
		case .none, .noneSkipFirst, .noneSkipLast: return image
		default: break
		}
		guard let backdrop = backdropColor(image) else { return image }
		let width = image.width
		let height = image.height
		guard
			let context = CGContext(
				data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
				space: image.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
				bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
					| CGBitmapInfo.byteOrder32Little.rawValue)
		else { return image }
		let bounds = CGRect(x: 0, y: 0, width: width, height: height)
		context.setFillColor(backdrop)
		context.fill(bounds)
		context.draw(image, in: bounds)
		return context.makeImage() ?? image
	}

	/// The colour of a capture's own translucent background — the semi-transparent pixels,
	/// with alpha divided out — so a see-through terminal gets its dark tint and a vibrancy
	/// sidebar its light one, and text stays readable. Nil when under 1% of the capture is
	/// see-through (no flattening needed); the opaque pixels' average when nothing is
	/// partly transparent; dark grey as a last resort.
	private static func backdropColor(_ image: CGImage) -> CGColor? {
		let side = 32
		var pixels = [UInt8](repeating: 0, count: side * side * 4)
		guard
			let context = CGContext(
				data: &pixels, width: side, height: side, bitsPerComponent: 8,
				bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
				bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
		else { return nil }
		context.interpolationQuality = .low
		context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
		// Sums of colour (alpha divided out) for partly transparent and for opaque pixels.
		var tinted = (r: 0.0, g: 0.0, b: 0.0, count: 0.0)
		var solid = (r: 0.0, g: 0.0, b: 0.0, count: 0.0)
		var transparent = 0
		for i in stride(from: 0, to: pixels.count, by: 4) {
			let alpha = Double(pixels[i + 3]) / 255
			if alpha < 0.98 { transparent += 1 }
			guard alpha > 0.04 else { continue }
			// Premultiplied: divide out alpha to get the colour itself.
			let r = min(Double(pixels[i]) / 255 / alpha, 1)
			let g = min(Double(pixels[i + 1]) / 255 / alpha, 1)
			let b = min(Double(pixels[i + 2]) / 255 / alpha, 1)
			if alpha < 0.95 {
				tinted = (tinted.r + r, tinted.g + g, tinted.b + b, tinted.count + 1)
			} else {
				solid = (solid.r + r, solid.g + g, solid.b + b, solid.count + 1)
			}
		}
		guard Double(transparent) / Double(side * side) >= 0.01 else { return nil }
		let source = tinted.count > 0 ? tinted : solid
		guard source.count > 0 else {
			return CGColor(srgbRed: 0.12, green: 0.12, blue: 0.13, alpha: 1)
		}
		return CGColor(
			srgbRed: source.r / source.count, green: source.g / source.count,
			blue: source.b / source.count, alpha: 1)
	}

	/// A saturated version of the window's dominant colour: samples a 16×16 downscale,
	/// weights each pixel by its saturation so white and black areas count little, then
	/// clamps saturation and brightness so the card reads as tinted glass.
	private static func averageColor(_ image: CGImage) -> NSColor {
		let side = 16
		var pixels = [UInt8](repeating: 0, count: side * side * 4)
		guard
			let context = CGContext(
				data: &pixels, width: side, height: side, bitsPerComponent: 8,
				bytesPerRow: side * 4,
				space: CGColorSpaceCreateDeviceRGB(),
				bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
		else { return .gray }
		context.interpolationQuality = .medium
		context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
		var r = 0.0
		var g = 0.0
		var b = 0.0
		var total = 0.0
		for i in stride(from: 0, to: pixels.count, by: 4) {
			let pr = Double(pixels[i]) / 255
			let pg = Double(pixels[i + 1]) / 255
			let pb = Double(pixels[i + 2]) / 255
			let maxC = max(pr, pg, pb)
			let minC = min(pr, pg, pb)
			let saturation = maxC == 0 ? 0 : (maxC - minC) / maxC
			let weight = 0.02 + saturation * saturation * maxC
			r += pr * weight
			g += pg * weight
			b += pb * weight
			total += weight
		}
		let base = NSColor(srgbRed: r / total, green: g / total, blue: b / total, alpha: 1)
		var hue: CGFloat = 0
		var sat: CGFloat = 0
		var bri: CGFloat = 0
		var alpha: CGFloat = 0
		base.usingColorSpace(.sRGB)?.getHue(&hue, saturation: &sat, brightness: &bri, alpha: &alpha)
		return NSColor(hue: hue, saturation: min(max(sat, 0.35), 0.75), brightness: 0.55, alpha: 1)
	}
}
