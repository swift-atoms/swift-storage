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
                guard !range.isEmpty else { return }
                unsafe (_base + Int(bitPattern: range.lowerBound.ordinal.rawValue))
                    .deinitialize(count: Int(bitPattern: range.count.underlying.rawValue))
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
        unsafe _base + Int(bitPattern: slot.ordinal.rawValue)
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

        let alignment = try! Memory.Alignment(MemoryLayout<Element>.alignment)
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
            guard !range.isEmpty else { return }
            let count = Int(bitPattern: range.count.underlying.rawValue)
            unsafe (out._base + Int(bitPattern: range.lowerBound.ordinal.rawValue)).initialize(
                from: _base + Int(bitPattern: range.lowerBound.ordinal.rawValue),
                count: count
            )
        }
        out._initialization = _initialization
        return out
    }
}

extension Storage.Contiguous: @unchecked Sendable
where Allocation: ~Copyable & Sendable, Element: ~Copyable & Sendable {}
#endif
