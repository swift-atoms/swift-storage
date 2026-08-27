public import Index
public import Tagged

extension Store {

    public struct Span<Element: ~Copyable & ~Escapable> {

        public let lowerBound: Index<Element>

        public let count: Index<Element>.Count

        @inlinable
        public init(start: Index<Element>, count: Index<Element>.Count) {
            self.lowerBound = start
            self.count = count
        }
    }
}

extension Store.Span: Sendable where Element: ~Copyable & ~Escapable {}

extension Store.Span: Equatable where Element: ~Copyable & ~Escapable {

    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.lowerBound == rhs.lowerBound && lhs.count == rhs.count
    }
}

extension Store.Span where Element: ~Copyable & ~Escapable {

    @inlinable
    public var upperBound: Index<Element> { lowerBound.advanced(by: count) }

    @inlinable
    public var isEmpty: Bool { count == .zero }
}
