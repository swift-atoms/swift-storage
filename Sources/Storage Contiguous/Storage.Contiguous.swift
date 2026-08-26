public import Index
public import Memory_Address
public import Memory_Alignment
public import Memory_Allocator_Primitive
public import Memory_Allocator_Protocol
public import Memory_Heap
public import Memory_Primitive
public import Memory_Region
public import Store_Initialization

extension Storage where Allocation: Memory.Region & ~Copyable {

    @safe
    @frozen
    public struct Contiguous<Element: ~Copyable>: ~Copyable {

        @usableFromInline
        internal var _capacity: Index<Element>.Count

        @usableFromInline
        internal var _initialization: Store.Initialization<Element>

        @usableFromInline
        internal var allocation: Allocation

        @inlinable
        public init(
            allocation: consuming Allocation,
            capacity: Index<Element>.Count,
            initialization: Store.Initialization<Element> = .empty
        ) {
            self.allocation = allocation
            self._capacity = capacity
            self._initialization = initialization
        }

        deinit {
            _initialization.forEach { range in
                guard !range.isEmpty else { return }
                unsafe (_base + Index<Element>.Offset(fromZero: range.lowerBound))
                    .deinitialize(count: range.count)
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
        unsafe _base + Index<Element>.Offset(fromZero: slot)
    }
}

extension Storage.Contiguous where Allocation: ~Copyable, Element: ~Copyable {

    @inlinable
    public var capacity: Index<Element>.Count { _capacity }

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

extension Storage.Contiguous where Allocation: ~Copyable, Element: ~Copyable {

    @inlinable
    public static func create<Resource: Memory.Growable & ~Copyable>(
        minimumCapacity: Index<Element>.Count
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
        minimumCapacity: Index<Element>.Count
    ) throws(__StorageContiguousError) where Allocation == Memory.Allocator<Resource> {
        let capacity = Int(bitPattern: minimumCapacity)
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

extension Storage.Contiguous where Allocation == Memory.Allocator<Memory.Heap>, Element: Copyable {

    @inlinable
    public borrowing func copy() -> Self {
        var out = Self.create(minimumCapacity: _capacity)
        _initialization.forEach { range in
            guard !range.isEmpty else { return }
            let offset = Index<Element>.Offset(fromZero: range.lowerBound)
            unsafe (out._base + offset).initialize(from: _base + offset, count: range.count)
        }
        out._initialization = _initialization
        return out
    }
}

extension Storage.Contiguous: @unchecked Sendable
where Allocation: ~Copyable & Sendable, Element: ~Copyable & Sendable {}
