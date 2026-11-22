import AppKit

/// The event tap's keys: Tab and the modifier drive the session, arrows move, typing
/// filters, Escape backs out one step at a time.
extension SwitcherController {
	func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
		let flags = event.flags
		let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
		let modifier = ownsKeyboard ? sessionModifier : Settings.modifier
		let modifierHeld = flags.contains(modifier.flag)
		let shift = flags.contains(.maskShift)

		switch type {
		case .flagsChanged:
			// Releasing the initializer commits the highlighted window. The release itself
			// passes through so the system's modifier state stays right.
			// Searching holds the session open (DockDoor's `_searchHoldsSession`).
			if ownsKeyboard, !modifierHeld, holdsOnModifier {
				commit()
			}
			return false

		case .keyDown:
			// A release the tap never saw: finish the session and let this key through.
			// The key event's own flags count too: only when both say the modifier is up.
			if ownsKeyboard, holdsOnModifier, !modifierHeld, !modifierPhysicallyHeld {
				commit()
				return false
			}
			if keyCode == Key.tab, modifierHeld, onlyInitializer(flags, modifier) {
				if ownsKeyboard { step(shift ? -1 : 1) } else { begin(backward: shift) }
				return true
			}
			if !ownsKeyboard, keyCode == Key.escape, settingsPanel.isVisible {
				settingsPanel.close()
				return true
			}
			guard ownsKeyboard else { return false }
			// Until the list arrives only navigation and Escape mean anything.
			if phase == .loading {
				switch keyCode {
				case Key.escape: cancel()
				case Key.returnKey, Key.keypadEnter: commit()
				case Key.left: move(.left)
				case Key.right: move(.right)
				case Key.up: move(.up)
				case Key.down: move(.down)
				default: break
				}
				return true
			}
			switch keyCode {
			case Key.escape:
				if state.drag != nil {
					dragTracker.reset()
					cancelDrag()
				} else if state.isShowingSettings {
					closeSettings()
				} else if !state.searchQuery.isEmpty {
					setQuery("")
				} else if !state.markedIDs.isEmpty {
					state.markedIDs = []
				} else {
					cancel()
				}
			case Key.returnKey, Key.keypadEnter: commit()
			case Key.left: move(.left)
			case Key.right: move(.right)
			case Key.up: move(.up)
			case Key.down: move(.down)
			case Key.delete:
				if !state.searchQuery.isEmpty { setQuery(String(state.searchQuery.dropLast())) }
			case Key.tab: step(shift ? -1 : 1)
			case Key.grave: stepWithinApp(shift ? -1 : 1)
			case Key.space where state.searchQuery.isEmpty:
				// Space marks the highlighted window for tiling (once typing has started it's
				// part of the query).
				if let id = state.selectedID { toggleMark(id) }
			case let key where modifierHeld && Key.digits.contains(key):
				// The modifier and 1–9: the board's presets, in order.
				tileWithPreset(at: Key.digits.firstIndex(of: key) ?? 0)
			default:
				// Typing filters: letters, digits and the like go into the query. There are
				// no letter shortcuts, so nothing else claims them.
				if let text = Self.typedText(event),
					!(state.searchQuery.isEmpty && text.allSatisfy(\.isWhitespace))
				{
					setQuery(state.searchQuery + text)
				}
			}
			// While a session is open every key belongs to it.
			return true

		case .keyUp:
			return ownsKeyboard

		case .scrollWheel:
			guard ownsKeyboard else { return false }
			scrolled(event)
			// Swallowed, so the window underneath doesn't scroll as well.
			return true

		default:
			return false
		}
	}

	/// Releasing the modifier ends the session, switching to the highlighted window — a
	/// filtered one included (not while settings are open, or in confirm mode).
	var holdsOnModifier: Bool {
		switchesOnRelease && state.drag == nil
	}

	/// The session ends when the modifier is let go (not in confirm mode or with settings
	/// open). A drag in progress holds it open until the drop.
	var switchesOnRelease: Bool {
		sessionMode == .onKeyRelease && !state.isShowingSettings
	}

	/// The modifier's actual state, read from the event system rather than inferred from
	/// the events the tap happened to see.
	var modifierPhysicallyHeld: Bool {
		CGEventSource.flagsState(.combinedSessionState).contains(sessionModifier.flag)
	}

	/// Tab with the initializer, optionally Shift, and no other primary modifier.
	func onlyInitializer(_ flags: CGEventFlags, _ modifier: InitializerModifier) -> Bool {
		let others: [CGEventFlags] = [.maskCommand, .maskAlternate, .maskControl].filter {
			$0 != modifier.flag
		}
		return others.allSatisfy { !flags.contains($0) }
	}

	static func typedText(_ event: CGEvent) -> String? {
		var length = 0
		var chars = [UniChar](repeating: 0, count: 8)
		event.keyboardGetUnicodeString(
			maxStringLength: 8, actualStringLength: &length, unicodeString: &chars)
		guard length > 0 else { return nil }
		let text = String(utf16CodeUnits: chars, count: length)
		return text.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) })
			? text : nil
	}
}
