import Affine_Standard_Library_Integration
public import Index
import Ordinal_Standard_Library_Integration

extension __StoreProtocol where Self: ~Copyable {

    @inlinable
    public func forEach<E: Swift.Error>(
        _ body: (borrowing Element) throws(E) -> Void
    ) throws(E) {
        var slot: Index<Element> = .zero
        let upper: Index<Element> = capacity.map(Ordinal.init)
        while slot < upper {
            try body(self[slot])
            slot += .one
        }
    }

    @inlinable
    public func reduce<Result, E: Swift.Error>(
        into initialResult: consuming Result,
        _ accumulate: (inout Result, borrowing Element) throws(E) -> Void
    ) throws(E) -> Result {
        var result = initialResult
        var slot: Index<Element> = .zero
        let upper: Index<Element> = capacity.map(Ordinal.init)
        while slot < upper {
            try accumulate(&result, self[slot])
            slot += .one
        }
        return result
    }

    @inlinable
    public func contains<E: Swift.Error>(
        where predicate: (borrowing Element) throws(E) -> Bool
    ) throws(E) -> Bool {
        var slot: Index<Element> = .zero
        let upper: Index<Element> = capacity.map(Ordinal.init)
        while slot < upper {
            if try predicate(self[slot]) { return true }
            slot += .one
        }
        return false
    }
}

extension __StoreProtocol where Self: ~Copyable, Element: Equatable {

    @inlinable
    public func contains(_ element: borrowing Element) -> Bool {

        var slot: Index<Element> = .zero
        let upper: Index<Element> = capacity.map(Ordinal.init)
        while slot < upper {
            if self[slot] == element { return true }
            slot += .one
        }
        return false
    }
}
