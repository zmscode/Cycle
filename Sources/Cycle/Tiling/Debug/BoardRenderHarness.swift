#if DEBUG
	import AppKit
	import RiftCore
	import SwiftUI

	/// `Cycle --render-board <folder>` (debug builds): renders the tiling board offscreen for
	/// scripted drags, one PNG per pointer position, so the board can be checked without
	/// dragging anything on screen.
	@MainActor
	enum BoardRenderHarness {
		private static let frame = CGRect(x: 0, y: 0, width: 1504, height: 846)
		private static let visible = CGRect(x: 0, y: 70, width: 1504, height: 746)
		private static let switcher = CGRect(x: 302, y: 340, width: 900, height: 180)

		static func run(into folder: URL) {
			try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
			let windows = [
				window(1, "Helium", CGRect(x: 0, y: 30, width: 747, height: 746)),
				window(2, "Zed", CGRect(x: 757, y: 30, width: 747, height: 746)),
				window(3, "TextEdit", CGRect(x: 300, y: 200, width: 600, height: 400)),
				window(4, "Notes", CGRect(x: 400, y: 250, width: 500, height: 400)),
			]
			let colors: [CGWindowID: NSColor] = [
				1: .systemTeal, 2: .systemPurple, 3: .systemOrange, 4: .systemGreen,
			]
			let state = SwitcherState()
			state.windows = windows
			state.recentOrder = windows
			for window in windows {
				state.images[window.id] = image(window.appName, colors[window.id] ?? .gray)
			}
			let halves: RiftLayout<CGWindowID> = .split(
				RiftSplit(axis: .horizontal, position: 0.5, first: .pane(1), second: .pane(2)))
			let presets = Settings.tilingPresets.isEmpty ? [.halves] : Settings.tilingPresets
			let placement = TilingOverlayPanel.placement(
				frame: frame, visible: visible, switcher: switcher, presets: presets)
			let board = TilingBoard(
				layout: halves,
				visible: CGRect(
					x: visible.minX, y: frame.maxY - visible.maxY, width: visible.width,
					height: visible.height),
				placement: placement, displayScale: 2)

			var log: [String] = []
			func render(_ name: String, dragging ids: [CGWindowID], at point: CGPoint) {
				var drag = WindowDrag(
					windowID: ids[0], windowIDs: ids, screen: NSScreen.main!, board: board,
					pointer: point, target: nil)
				drag.target = board.target(at: point, dragging: ids)
				state.drag = drag
				let crop = placement.card.insetBy(dx: -90, dy: -90)
				let view = TilingOverlayView(state: state)
					.frame(width: frame.width, height: frame.height)
					.background(Color(white: 0.12))
				let renderer = ImageRenderer(content: view)
				renderer.scale = 2
				guard let cg = renderer.cgImage,
					let cropped = cg.cropping(
						to: CGRect(
							x: crop.minX * 2, y: crop.minY * 2, width: crop.width * 2,
							height: crop.height * 2))
				else { return }
				let rep = NSBitmapImageRep(cgImage: cropped)
				try? rep.representation(using: .png, properties: [:])?.write(
					to: folder.appending(path: "\(name).png"))
				log.append(
					"\(name)\t\(String(describing: drag.target))\tpreview: \(drag.preview.map { String(describing: $0.paneIDs) } ?? "none")"
				)
			}

			let b = placement.screen
			// Sweeps across the board's middle, dragging an untiled window and a tiled one.
			for step in 0...10 {
				let x = b.minX + 4 + (b.width - 8) * CGFloat(step) / 10
				render(
					String(format: "a-untiled-x%02d", step), dragging: [3],
					at: CGPoint(x: x, y: b.midY))
				render(
					String(format: "b-tiled-x%02d", step), dragging: [1],
					at: CGPoint(x: x, y: b.midY))
			}
			for step in 0...6 {
				let y = b.minY + 4 + (b.height - 8) * CGFloat(step) / 6
				render(
					String(format: "c-untiled-y%02d", step), dragging: [3],
					at: CGPoint(x: b.midX + b.width / 4, y: y))
			}
			render(
				"d-group-center", dragging: [3, 4],
				at: CGPoint(x: b.minX + b.width * 0.75, y: b.midY))
			for chip in placement.chips {
				render(
					"e-chip-\(chip.preset.rawValue)", dragging: [3, 4],
					at: CGPoint(x: chip.rect.minX + 4, y: chip.rect.minY + 4))
			}
			// Rows close up in proportion.
			let thirds = TilingPreset.thirds.layout(mainShare: 0.6).mapPanes { CGWindowID($0 + 1) }
			let uneven: RiftLayout<CGWindowID> = .split(
				RiftSplit(
					axis: .horizontal, position: 0.6, first: .pane(1),
					second: .split(
						RiftSplit(axis: .horizontal, position: 0.5, first: .pane(2), second: .pane(3)))))
			for (name, tree) in [("thirds", thirds), ("60-20-20", uneven)] {
				let rest = tree.removingProportionally(2)
				let frames = rest?.geometry(
					in: CGRect(x: 0, y: 0, width: 1200, height: 100),
					metrics: RiftMetrics(dividerThickness: 0, minimumPaneSize: .zero)
				).paneFrames ?? [:]
				log.append("remove 2 from \(name): " + frames.sorted { $0.key < $1.key }
					.map { "\($0.key)=\(Int($0.value.width))" }.joined(separator: " "))
			}
			try? log.joined(separator: "\n").write(
				to: folder.appending(path: "log.txt"), atomically: true, encoding: .utf8)
			print("rendered \(log.count) frames to \(folder.path)")
		}

		private static func window(_ id: CGWindowID, _ name: String, _ bounds: CGRect)
			-> SwitcherWindow
		{
			SwitcherWindow(
				id: id, pid: 0, appName: name, bundleID: "test.\(name)", title: name,
				bounds: bounds, axElement: nil, isMinimized: false, isAppHidden: false,
				isOnOtherSpace: false, isWindowless: false)
		}

		private static func image(_ text: String, _ color: NSColor) -> NSImage {
			NSImage(size: CGSize(width: 800, height: 600), flipped: false) { rect in
				color.setFill()
				rect.fill()
				let attributes: [NSAttributedString.Key: Any] = [
					.font: NSFont.boldSystemFont(ofSize: 120), .foregroundColor: NSColor.white,
				]
				(text as NSString).draw(at: CGPoint(x: 40, y: 220), withAttributes: attributes)
				return true
			}
		}
	}
#endif
