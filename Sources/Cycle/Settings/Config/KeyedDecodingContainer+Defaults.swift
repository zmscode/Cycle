import Foundation

extension KeyedDecodingContainer {
	/// The value for `key`, or `fallback` when it's missing or the wrong type, so one bad
	/// entry in a hand-edited file doesn't throw the rest away.
	func value<T: Decodable>(_ key: Key, default fallback: T) -> T {
		(try? decodeIfPresent(T.self, forKey: key)) ?? fallback
	}
}
