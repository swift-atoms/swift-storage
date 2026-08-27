public import Index

extension __StoreProtocol where Self: ~Copyable, Element: Copyable {

    @inlinable
    public mutating func fill(range: Store.Span<Element>, with element: borrowing Element) {
        var slot = range.lowerBound
        let upper = range.upperBound
        while slot < upper {
            initialize(at: slot, to: copy element)
            slot += .one
        }
    }

    @inlinable
    public mutating func fill(with element: borrowing Element) {
        fill(range: Store.Span(start: .zero, count: capacity), with: element)
    }
}
