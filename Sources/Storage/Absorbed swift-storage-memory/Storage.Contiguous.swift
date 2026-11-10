#if Memory
    public import Ordinal
    public import Cardinal
    public import Index
    public import Memory
    public import Memory_Allocator
    public import Memory_Allocator_Protocol
    public import Store
    public import Tagged

    extension Storage where Allocation: Memory.Region & ~Copyable {

        @safe
        @frozen
        public struct Contiguous<Element: ~Copyable>: ~Copyable {

            @usableFromInline
            internal var _capacity: Tagged<Element, Cardinal>

            @usableFromInline
            internal var _initialization: Store.Initialization<Element>

            @usableFromInline
            internal var allocation: Allocation

            @inlinable
            public init(
                allocation: consuming Allocation,
                capacity: Tagged<Element, Cardinal>,
                initialization: Store.Initialization<Element> = .empty
            ) {
                self.allocation = allocation
                self._capacity = capacity
                self._initialization = initialization
            }

            deinit {
                _initialization.forEach { range in
                    unsafe _slots(range).deinitialize()
                }
            }
        }
    }

    extension Storage.Contiguous where Allocation: Memory.Region & ~Copyable, Element: ~Copyable {

        @inlinable
        package var _base: UnsafeMutablePointer<Element> {
            unsafe allocation.base.mutablePointer.assumingMemoryBound(to: Element.self)
        }

        @inlinable
        package func _ptr(at slot: Index<Element>) -> UnsafeMutablePointer<Element> {
            precondition(
                slot < _capacity.map(Ordinal.init),
                "Storage.Contiguous: slot is outside the capacity"
            )
            return unsafe _base + Int(bitPattern: slot.ordinal.rawValue)
        }

        /// The run of slots `range` covers.
        ///
        /// The bulk operations reach their slots through this and `_slots(first:)`, so the step from typed slots
        /// and counts to a pointer and a length is taken here and nowhere else.
        ///
        /// - Precondition: a non-empty `range` lies within the capacity.
        @inlinable
        package func _slots(_ range: Swift::Range<Index<Element>>) -> UnsafeMutableBufferPointer<Element> {
            let lower = Int(bitPattern: range.lowerBound.ordinal.rawValue)
            let upper = Int(bitPattern: range.upperBound.ordinal.rawValue)
            precondition(
                lower == upper || upper <= Int(bitPattern: _capacity.underlying.rawValue),
                "Storage.Contiguous: slot is outside the capacity"
            )
            return unsafe UnsafeMutableBufferPointer(start: _base + lower, count: upper - lower)
        }

        /// The run of the first `count` slots.
        ///
        /// - Precondition: `count` does not exceed the capacity.
        @inlinable
        package func _slots(first count: Index<Element>.Count) -> UnsafeMutableBufferPointer<Element> {
            let length = Int(bitPattern: count.underlying.rawValue)
            precondition(
                length <= Int(bitPattern: _capacity.underlying.rawValue),
                "Storage.Contiguous: slot is outside the capacity"
            )
            return unsafe UnsafeMutableBufferPointer(start: _base, count: length)
        }
    }

    extension Storage.Contiguous where Allocation: ~Copyable, Element: ~Copyable {

        @inlinable
        public var capacity: Tagged<Element, Cardinal> { _capacity }

        @inlinable
        public var count: Tagged<Element, Cardinal> { _initialization.count }

        @inlinable
        public var isEmpty: Bool { _initialization.isEmpty }

        @inlinable
        public var initialization: Store.Initialization<Element> {
            get { _initialization }
            set { _initialization = newValue }
        }
    }

    extension Storage.Contiguous where Allocation: ~Copyable, Element: ~Copyable {

        @inlinable
        public static func create<Resource: Memory.Growable & ~Copyable>(
            minimumCapacity: Tagged<Element, Cardinal>
        ) -> Self where Allocation == Memory.Allocator<Resource> {
            do {
                return try Self(minimumCapacity: minimumCapacity)
            } catch {
                preconditionFailure(
                    "Storage.Contiguous capacity \(minimumCapacity) * stride \(MemoryLayout<Element>.stride) overflows the byte-count domain"
                )
            }
        }

        @inlinable
        public init<Resource: Memory.Growable & ~Copyable>(
            minimumCapacity: Tagged<Element, Cardinal>
        ) throws(__StorageContiguousError) where Allocation == Memory.Allocator<Resource> {
            let capacity = Int(bitPattern: minimumCapacity.underlying.rawValue)
            let (capacityInBytes, overflowed) = capacity.multipliedReportingOverflow(
                by: MemoryLayout<Element>.stride
            )
            guard capacity >= 0, !overflowed else {
                throw .overflow(capacity: capacity, stride: MemoryLayout<Element>.stride)
            }
            let byteCount = Memory.Address.Count(UInt(capacityInBytes))

            let alignment: Memory.Alignment
            do {
                alignment = try Memory.Alignment(MemoryLayout<Element>.alignment)
            } catch {
                preconditionFailure("Natural alignment of a Swift type is a valid alignment: \(error)")
            }
            let allocation = Memory.Allocator(Resource(byteCount: byteCount, alignment: alignment))
            self.init(allocation: allocation, capacity: minimumCapacity)
        }
    }

    extension Storage.Contiguous where Allocation: ~Copyable, Element: Copyable {

        @inlinable
        public borrowing func copy<Resource: Memory.Growable & ~Copyable>() -> Self
        where Allocation == Memory.Allocator<Resource> {
            var out = Self.create(minimumCapacity: _capacity)
            _initialization.forEach { range in
                _ = unsafe out._slots(range).initialize(fromContentsOf: _slots(range))
            }
            out._initialization = _initialization
            return out
        }
    }

    extension Storage.Contiguous: @unchecked Sendable
    where Allocation: ~Copyable & Sendable, Element: ~Copyable & Sendable {}
#endif
