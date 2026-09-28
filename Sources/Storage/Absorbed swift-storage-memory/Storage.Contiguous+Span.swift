#if Memory
public import Cardinal
public import Memory
public import Span
public import Store
public import Tagged

extension Storage.Contiguous where Allocation: Memory.Region & ~Copyable, Element: ~Copyable {

    @inlinable
    package func _assertPrefixShapedLedger(_ function: StaticString = #function) {
        assert(
            _initialization.isPrefixShaped,
            "\(function): requires a prefix-shaped ledger ([0, count)); the current ledger is "
                + "wrapped or offset — a composing discipline synced a non-prefix shape "
                + "(e.g. Buffer.Ring) and must not use this accessor"
        )
    }

    @inlinable
    public var span: Swift.Span<Element> {
        @_lifetime(borrow self)
        get {
            _assertPrefixShapedLedger()
            let span = unsafe Swift.Span(
                _unsafeStart: _base,
                count: Int(bitPattern: count.underlying.rawValue)
            )
            return unsafe _overrideLifetime(span, borrowing: self)
        }
    }

    @inlinable
    public var mutableSpan: Swift.MutableSpan<Element> {
        @_lifetime(&self)
        mutating get {
            _assertPrefixShapedLedger()
            let span = unsafe Swift.MutableSpan(
                _unsafeStart: _base,
                count: Int(bitPattern: count.underlying.rawValue)
            )
            return unsafe _overrideLifetime(span, mutating: &self)
        }
    }

    @inlinable
    public var outputSpan: Swift.OutputSpan<Element> {
        @_lifetime(&self)
        _modify {
            _assertPrefixShapedLedger()
            let cap = Int(bitPattern: _capacity.underlying.rawValue)
            var output = unsafe Swift.OutputSpan<Element>(
                buffer: unsafe UnsafeMutableBufferPointer(start: _base, count: cap),
                initializedCount: Int(bitPattern: count.underlying.rawValue)
            )
            defer {
                let committed = unsafe output.finalize(
                    for: unsafe UnsafeMutableBufferPointer(start: _base, count: cap)
                )
                output = Swift.OutputSpan<Element>()
                _initialization = .linear(count: Tagged<Element, Cardinal>(UInt(committed)))
            }
            yield &output
        }
        @_lifetime(borrow self)
        _read {
            _assertPrefixShapedLedger()
            let cap = Int(bitPattern: _capacity.underlying.rawValue)
            var output = unsafe Swift.OutputSpan<Element>(
                buffer: unsafe UnsafeMutableBufferPointer(start: _base, count: cap),
                initializedCount: Int(bitPattern: count.underlying.rawValue)
            )
            defer {
                _ = unsafe output.finalize(
                    for: unsafe UnsafeMutableBufferPointer(start: _base, count: cap)
                )
                output = Swift.OutputSpan<Element>()
            }
            yield output
        }
    }

    @inlinable
    public mutating func withOutputSpan<R: ~Copyable, Failure: Swift.Error>(
        addingCapacity budget: Tagged<Element, Cardinal>,
        _ body: (inout Swift.OutputSpan<Element>) throws(Failure) -> R
    ) throws(Failure) -> R {
        _assertPrefixShapedLedger()
        let frontier = Int(bitPattern: count.underlying.rawValue)
        let window = Int(bitPattern: budget.underlying.rawValue)
        precondition(
            frontier + window <= Int(bitPattern: _capacity.underlying.rawValue),
            "Storage.Contiguous.withOutputSpan(addingCapacity:): window exceeds capacity"
        )
        let start = unsafe _base + frontier
        var output = unsafe Swift.OutputSpan<Element>(
            buffer: unsafe UnsafeMutableBufferPointer(start: start, count: window),
            initializedCount: 0
        )
        defer {
            let committed = unsafe output.finalize(
                for: unsafe UnsafeMutableBufferPointer(start: start, count: window)
            )
            output = Swift.OutputSpan<Element>()
            _initialization = .linear(count: Tagged<Element, Cardinal>(UInt(frontier + committed)))
        }
        return try body(&output)
    }
}

extension Storage.Contiguous: Span.`Protocol`
where Allocation: Memory.Region & ~Copyable, Element: ~Copyable {}

extension Storage.Contiguous
where Allocation: Memory.Region & ~Copyable, Element: ~Copyable {

    @_lifetime(&self)
    @inlinable
    public mutating func mutableSpan(count: Tagged<Element, Cardinal>) -> Swift.MutableSpan<Element> {
        _assertPrefixShapedLedger()
        let span = unsafe Swift.MutableSpan(
            _unsafeStart: _base,
            count: Int(bitPattern: count.underlying.rawValue)
        )
        return unsafe _overrideLifetime(span, mutating: &self)
    }
}
#endif
