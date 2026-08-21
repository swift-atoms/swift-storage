import Affine_Primitives_Standard_Library_Integration
public import Index_Primitives
public import Memory_Region_Primitives
import Ordinal_Primitives_Standard_Library_Integration
public import Store_Initialization_Primitives
public import Store_Protocol_Primitives

extension Storage.Contiguous where Allocation: Memory.Region & ~Copyable, Element: ~Copyable {

    @inlinable
    public subscript(slot: Index<Element>) -> Element {
        _read {
            let pointer = unsafe _ptr(at: slot)
            yield unsafe pointer.pointee
        }
        _modify {
            let pointer = unsafe _ptr(at: slot)
            yield &(unsafe pointer.pointee)
        }
    }

    @inlinable
    public mutating func initialize(at slot: Index<Element>, to element: consuming Element) {
        unsafe _ptr(at: slot).initialize(to: element)
        _initialization = .linear(count: count + .one)
    }

    @inlinable
    public mutating func move(at slot: Index<Element>) -> Element {
        let element = unsafe _ptr(at: slot).move()
        _initialization = .linear(count: count.subtract.saturating(.one))
        return element
    }
}

extension Storage.Contiguous where Allocation: Memory.Region & ~Copyable, Element: ~Copyable {

    @inlinable
    package func _isValidPrefixTailRemoval(range removed: Swift.Range<Index<Element>>) -> Bool {
        guard initialization.isPrefixShaped, !removed.isEmpty else { return true }
        return removed.upperBound == initialization.count.map(Ordinal.init)
    }

    @inlinable
    public mutating func deinitialize(at slot: Index<Element>) {
        let removed = Swift.Range<Index<Element>>(start: slot, count: .one)
        assert(
            _isValidPrefixTailRemoval(range: removed),
            "Storage.Contiguous.deinitialize(at:): slot is not the ledger's tail — move(at:)'s "
                + "linear-prefix self-maintenance is truthful only for LIFO (tail) removal; a "
                + "non-tail removal must re-sync `initialization` explicitly "
                + "(Store.Ledgered.Protocol)"
        )
        _ = move(at: slot)
    }

    @inlinable
    public mutating func deinitialize(range: Swift.Range<Index<Element>>) {
        assert(
            _isValidPrefixTailRemoval(range: range),
            "Storage.Contiguous.deinitialize(range:): range is not the ledger's tail range — "
                + "move(at:)'s linear-prefix self-maintenance is truthful only for LIFO (tail) "
                + "removal; a non-tail removal must re-sync `initialization` explicitly "
                + "(Store.Ledgered.Protocol)"
        )
        var slot = range.lowerBound
        while slot < range.upperBound {
            _ = move(at: slot)
            slot += .one
        }
    }
}

extension Storage.Contiguous: Store.`Protocol`
where Allocation: Memory.Region & ~Copyable, Element: ~Copyable {}
