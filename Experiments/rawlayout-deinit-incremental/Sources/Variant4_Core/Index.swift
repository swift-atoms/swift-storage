// MARK: - Simplified Index<Element> to mirror real package structure
// This mimics Index_Primitives.Index<Element> without the external dependency

public struct Index<Element: ~Copyable>: Sendable, Equatable, Comparable, Hashable {
    public let rawValue: Int

    public init(_ rawValue: Int) {
        self.rawValue = rawValue
    }

    public static var zero: Self { Self.init(0) }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var successor: Self { Self(rawValue + 1) }
}

extension Index: ExpressibleByIntegerLiteral where Element: Copyable {
    public init(integerLiteral value: Int) {
        self.rawValue = value
    }
}
