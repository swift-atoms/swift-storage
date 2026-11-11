#if Memory
    public import Ordinal
    public import Cardinal
    public import Index
    public import Memory
    public import Store
    public import Tagged
    import Carrier

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
            _initialization = Self._prefix(_initialized + 1)
        }

        @inlinable
        public mutating func move(at slot: Index<Element>) -> Element {
            let element = unsafe _ptr(at: slot).move()
            _initialization = Self._prefix(_initialized - 1)
            return element
        }
    }

    extension Storage.Contiguous where Allocation: Memory.Region & ~Copyable, Element: ~Copyable {

        @inlinable
        package func _isValidPrefixTailRemoval(range removed: Swift::Range<Index<Element>>) -> Bool {
            guard initialization.isPrefixShaped, !removed.isEmpty else { return true }
            return removed.upperBound == Index<Element>(_unchecked: Ordinal(initialization.count.underlying))
        }

        @inlinable
        public mutating func deinitialize(at slot: Index<Element>) {
            let removed = slot..<slot + Tagged<Element, Cardinal>.one
            precondition(
                _isValidPrefixTailRemoval(range: removed),
                "Storage.Contiguous.deinitialize(at:): slot is not the ledger's tail — move(at:)'s "
                    + "linear-prefix self-maintenance is truthful only for LIFO (tail) removal; a "
                    + "non-tail removal must re-sync `initialization` explicitly "
                    + "(Store.Ledgered.Protocol)"
            )
            _ = move(at: slot)
        }

        @inlinable
        public mutating func deinitialize(range: Swift::Range<Index<Element>>) {
            precondition(
                _isValidPrefixTailRemoval(range: range),
                "Storage.Contiguous.deinitialize(range:): range is not the ledger's tail range — "
                    + "move(at:)'s linear-prefix self-maintenance is truthful only for LIFO (tail) "
                    + "removal; a non-tail removal must re-sync `initialization` explicitly "
                    + "(Store.Ledgered.Protocol)"
            )
            unsafe _slots(range).deinitialize()
            _initialization = .linear(count: count.subtract.saturating(range.count))
        }

        /// Moves the elements in slots `0..<count` into the same slots of `destination`, in one pass.
        ///
        /// Both ledgers end as if each element had left through `move(at:)` and arrived through
        /// `initialize(at:to:)`.
        @inlinable
        public mutating func move(to destination: inout Self, count: Index<Element>.Count) {
            _ = unsafe destination._slots(first: count).moveInitialize(fromContentsOf: _slots(first: count))
            _initialization = .linear(count: self.count.subtract.saturating(count))
            destination._initialization = .linear(count: destination.count + count)
        }
    }

    extension Storage.Contiguous where Allocation: Memory.Region & ~Copyable, Element: Copyable {

        /// Writes `element` into every slot of a vacant storage, in one pass.
        @inlinable
        public mutating func fill(with element: borrowing Element) {
            precondition(isEmpty, "Storage.Contiguous.fill(with:): the storage must be vacant")
            unsafe _slots(first: _capacity).initialize(repeating: copy element)
            _initialization = .linear(count: _capacity)
        }

        /// Copies the elements in slots `0..<count` into the same slots of `destination`, in one pass.
        ///
        /// The destination's ledger ends as if each element had arrived through `initialize(at:to:)`.
        @inlinable
        public func copy(to destination: inout Self, count: Index<Element>.Count) {
            _ = unsafe destination._slots(first: count).initialize(fromContentsOf: _slots(first: count))
            destination._initialization = .linear(count: destination.count + count)
        }
    }

    extension Storage.Contiguous: Store.`Protocol`
    where Allocation: Memory.Region & ~Copyable, Element: ~Copyable {}
#endif
