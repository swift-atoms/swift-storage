public import Index

extension __StoreProtocol where Self: ~Copyable {

    @inlinable
    public mutating func deinitialize(at slot: Index<Element>) {
        _ = move(at: slot)
    }

    @inlinable
    public mutating func deinitialize(range: Store.Span<Element>) {
        var slot = range.lowerBound
        let upper = range.upperBound
        while slot < upper {
            _ = move(at: slot)
            slot += .one
        }
    }

    @inlinable
    public mutating func clear() {
        deinitialize(range: Store.Span(start: .zero, count: capacity))
    }

    @inlinable
    public mutating func removeAll() {
        clear()
    }
}
