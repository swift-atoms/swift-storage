public import Index
public import Memory_Region
public import Span_Protocol
public import Store_Initialization

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
            let span = unsafe Swift.Span(_unsafeStart: _base, count: Int(bitPattern: count))
            return unsafe _overrideLifetime(span, borrowing: self)
        }
    }

    @inlinable
    public var mutableSpan: Swift.MutableSpan<Element> {
        @_lifetime(&self)
        mutating get {
            _assertPrefixShapedLedger()
            let span = unsafe Swift.MutableSpan(_unsafeStart: _base, count: Int(bitPattern: count))
            return unsafe _overrideLifetime(span, mutating: &self)
        }
    }

    @inlinable
    public var outputSpan: Swift.OutputSpan<Element> {
        @_lifetime(&self)
        _modify {
            _assertPrefixShapedLedger()
            let cap = Int(bitPattern: _capacity)
            var output = unsafe Swift.OutputSpan(
                buffer: unsafe UnsafeMutableBufferPointer(start: _base, count: cap),
                initializedCount: Int(bitPattern: count)
            )
            defer {
                let committed = unsafe output.finalize(
                    for: unsafe UnsafeMutableBufferPointer(start: _base, count: cap)
                )
                output = Swift.OutputSpan()
                _initialization = .linear(count: Index<Element>.Count(UInt(committed)))
            }
            yield &output
        }
        @_lifetime(borrow self)
        _read {
            _assertPrefixShapedLedger()
            let cap = Int(bitPattern: _capacity)
            var output = unsafe Swift.OutputSpan(
                buffer: unsafe UnsafeMutableBufferPointer(start: _base, count: cap),
                initializedCount: Int(bitPattern: count)
            )
            defer {
                _ = unsafe output.finalize(
                    for: unsafe UnsafeMutableBufferPointer(start: _base, count: cap)
                )
                output = Swift.OutputSpan()
            }
            yield output
        }
    }

    @inlinable
    public mutating func withOutputSpan<R: ~Copyable, Failure: Swift.Error>(
        addingCapacity budget: Index<Element>.Count,
        _ body: (inout Swift.OutputSpan<Element>) throws(Failure) -> R
    ) throws(Failure) -> R {
        _assertPrefixShapedLedger()
        let frontier = Int(bitPattern: count)
        let window = Int(bitPattern: budget)
        precondition(
            frontier + window <= Int(bitPattern: _capacity),
            "Storage.Contiguous.withOutputSpan(addingCapacity:): window exceeds capacity"
        )
        let start = unsafe _base + frontier
        var output = unsafe Swift.OutputSpan(
            buffer: unsafe UnsafeMutableBufferPointer(start: start, count: window),
            initializedCount: 0
        )
        defer {
            let committed = unsafe output.finalize(
                for: unsafe UnsafeMutableBufferPointer(start: start, count: window)
            )
            output = Swift.OutputSpan()
            _initialization = .linear(count: Index<Element>.Count(UInt(frontier + committed)))
        }
        return try body(&output)
    }
}

extension Storage.Contiguous: Span.`Protocol`
where Allocation: Memory.Region & ~Copyable, Element: ~Copyable {}

extension Storage.Contiguous: Span.Mutable.`Protocol`
where Allocation: Memory.Region & ~Copyable, Element: ~Copyable {

    @_lifetime(&self)
    @inlinable
    public mutating func mutableSpan(count: Index<Element>.Count) -> Swift.MutableSpan<Element> {
        _assertPrefixShapedLedger()
        let span = unsafe Swift.MutableSpan(_unsafeStart: _base, count: Int(bitPattern: count))
        return unsafe _overrideLifetime(span, mutating: &self)
    }
}
