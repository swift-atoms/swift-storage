public import Index

extension Store.Initialization where Element: ~Copyable & ~Escapable {

    @inlinable
    public var count: Index.Index<Element>.Count {
        switch self {
        case .empty:
            return .zero

        case .one(let span):
            return span.count

        case .two(let first, let second):
            return first.count + second.count
        }
    }

    @inlinable
    public var isEmpty: Bool {
        switch self {
        case .empty:
            return true

        case .one(let span):
            return span.isEmpty

        case .two(let first, let second):
            return first.isEmpty && second.isEmpty
        }
    }
}

extension Store.Initialization where Element: ~Copyable & ~Escapable {

    @inlinable
    public var isPrefixShaped: Bool {
        switch self {
        case .empty:
            return true

        case .one(let range):
            return range.lowerBound == .zero

        case .two:
            return false
        }
    }
}

extension Store.Initialization where Element: ~Copyable & ~Escapable {

    @inlinable
    public func forEach(
        _ body: (Swift.Range<Index<Element>>) -> Void
    ) {
        switch self {
        case .empty: break
        case .one(let range): body(range)

        case .two(let first, let second):
            body(first)
            body(second)
        }
    }
}

extension Store.Initialization where Element: ~Copyable & ~Escapable {

    @inlinable
    public func linearize(
        _ body: (Swift.Range<Index<Element>>, _ offset: Index<Element>) -> Void
    ) {
        var offset: Index<Element> = .zero
        forEach { range in
            body(range, offset)
            offset += range.count
        }
    }
}

extension Store.Initialization where Element: ~Copyable & ~Escapable {

    @inlinable
    public static func linear(count: Index<Element>.Count) -> Self {
        guard count > .zero else { return .empty }
        return .one(Swift.Range<Index<Element>>(start: .zero, count: count))
    }
}
