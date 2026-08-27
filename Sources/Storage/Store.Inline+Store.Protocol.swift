public import Index

extension Store.Inline where Element: ~Copyable {

    @inlinable
    public var capacity: Index<Element>.Count { Index<Element>.Count(UInt(n)) }

    @inlinable
    public var count: Index<Element>.Count { _initialization.count }

    @inlinable
    public var isEmpty: Bool { _initialization.isEmpty }

    @inlinable
    public var initialization: Store.Initialization<Element> {
        get { _initialization }
        set { _initialization = newValue }
    }
}

extension Store.Inline where Element: ~Copyable {

    @inlinable
    package func _readBase() -> UnsafePointer<Element> {
        withUnsafePointer(to: _storage) {
            unsafe UnsafeRawPointer($0).assumingMemoryBound(to: Element.self)
        }
    }

    @inlinable
    package mutating func _mutableBase() -> UnsafeMutablePointer<Element> {
        withUnsafeMutablePointer(to: &_storage) {
            unsafe UnsafeMutableRawPointer($0).assumingMemoryBound(to: Element.self)
        }
    }
}

extension Store.Inline where Element: ~Copyable {

    @inlinable
    public subscript(slot: Index<Element>) -> Element {
        _read {
            let pointer = unsafe _readBase() + slot
            yield unsafe pointer.pointee
        }
        _modify {
            let pointer = unsafe _mutableBase() + slot
            yield &(unsafe pointer.pointee)
        }
    }

    @inlinable
    public mutating func initialize(at slot: Index<Element>, to element: consuming Element) {

        let pointer = unsafe _mutableBase() + slot
        unsafe pointer.initialize(to: element)
        _initialization = .linear(count: count + .one)
    }

    @inlinable
    public mutating func move(at slot: Index<Element>) -> Element {
        let element = withUnsafeMutablePointer(to: &_storage) { raw -> Element in
            let base = unsafe UnsafeMutableRawPointer(raw).assumingMemoryBound(to: Element.self)
            let pointer = unsafe base + slot
            return unsafe pointer.move()
        }
        _initialization = .linear(count: count.subtracting(saturating: .one))
        return element
    }
}

extension Store.Inline where Element: ~Copyable {

    @inlinable
    package func _isValidPrefixTailRemoval(range removed: Store.Span<Element>) -> Bool {
        guard initialization.isPrefixShaped, !removed.isEmpty else { return true }
        return removed.upperBound == Index<Element>(initialization.count)
    }

    @inlinable
    public mutating func deinitialize(at slot: Index<Element>) {
        let removed = Store.Span<Element>(start: slot, count: .one)
        assert(
            _isValidPrefixTailRemoval(range: removed),
            "Store.Inline.deinitialize(at:): slot is not the ledger's tail — move(at:)'s "
                + "linear-prefix self-maintenance is truthful only for LIFO (tail) removal; a "
                + "non-tail removal must re-sync `initialization` explicitly "
                + "(Store.Ledgered.Protocol)"
        )
        _ = move(at: slot)
    }

    @inlinable
    public mutating func deinitialize(range: Store.Span<Element>) {
        assert(
            _isValidPrefixTailRemoval(range: range),
            "Store.Inline.deinitialize(range:): range is not the ledger's tail range — "
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

extension Store.Inline: Store.`Protocol` where Element: ~Copyable {}
