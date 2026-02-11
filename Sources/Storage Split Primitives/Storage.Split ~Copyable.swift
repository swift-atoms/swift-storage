// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Storage_Primitives_Core

// MARK: - Layout Computation

extension Storage.Split where Element: ~Copyable {
    /// Computes the byte offset where the element region begins.
    @inlinable
    static func _elementRegionOffset(capacity: Index<Element>.Count) -> Memory.Address.Count {
        let laneBytes: Memory.Address.Count = capacity.retag(Lane.self) * .stride
        let elementAlignment = try! Memory.Alignment(max(MemoryLayout<Element>.alignment, 1))
        return elementAlignment.align.up(laneBytes)
    }

    /// Total bytes needed for the raw elements region of the ManagedBuffer.
    @inlinable
    static func _totalBytes(capacity: Index<Element>.Count) -> Memory.Address.Count {
        return _elementRegionOffset(capacity: capacity) + capacity * .stride
    }
}

// MARK: - Factory

extension Storage.Split where Element: ~Copyable {
    /// Creates split storage with the given capacity.
    ///
    /// Both lanes are uninitialized. The consumer must initialize slots
    /// before accessing them.
    ///
    /// - Parameter capacity: The number of slots to allocate per lane.
    /// - Returns: A new split storage instance.
    @inlinable
    public static func create(
        capacity: Index<Element>.Count
    ) -> Storage.Split<Lane> {
        let bytes = _totalBytes(capacity: capacity)

        return unsafe unsafeDowncast(
            Storage.Split<Lane>.create(minimumCapacity: Int(bitPattern: bytes.cardinal)) { _ in
                Header(capacity: capacity)
            },
            to: Storage.Split<Lane>.self
        )
    }
}

// MARK: - Properties

extension Storage.Split where Element: ~Copyable {
    /// Storage capacity in slot count.
    @inlinable
    public var slotCapacity: Index<Element>.Count {
        header.capacity
    }
}

// MARK: - Field Handles

extension Storage.Split where Element: ~Copyable {
    /// The field handle for the lane (secondary/metadata) array.
    ///
    /// The lane array starts at byte 0 of the elements region.
    @inlinable
    public var laneField: Storage.Field<Lane> {
        Storage.Field<Lane>(
            _offset: .zero,
            _stride: .stride
        )
    }

    /// The field handle for the element (primary/payload) array.
    ///
    /// The element array starts after the lane array, aligned to
    /// `MemoryLayout<Element>.alignment`. The offset is derived from
    /// `header.capacity` on each access — capture the handle once
    /// and reuse it to avoid recomputation.
    @inlinable
    public var elementField: Storage.Field<Element> {
        Storage.Field<Element>(
            _offset: Memory.Address.Offset(Storage.Split<Lane>._elementRegionOffset(capacity: header.capacity)),
            _stride: .stride
        )
    }
}

// MARK: - Core Access Primitive

extension Storage.Split where Element: ~Copyable {
    /// Returns a mutable pointer to the value at the given slot in the given field.
    ///
    /// This is the core access primitive. ALL other access methods delegate to this.
    ///
    /// - Parameters:
    ///   - field: The field handle identifying which array to access.
    ///   - slot: The physical slot coordinate.
    /// - Returns: A mutable pointer to the value.
    /// - Warning: The caller must ensure the slot is valid and within capacity.
    @unsafe
    @inlinable
    public func pointer<Value: ~Copyable>(
        _ field: Storage.Field<Value>, at slot: Index<Element>
    ) -> UnsafeMutablePointer<Value> {
        assert(
            slot < slotCapacity,
            "Storage.Split: slot out of bounds for capacity"
        )
        return unsafe withUnsafeMutablePointerToElements { base in
            unsafe UnsafeMutableRawPointer(base)
                .advanced(by: field._offset + Index<Element>.Offset(fromZero: slot).retag(Value.self) * field._stride)
                .assumingMemoryBound(to: Value.self)
        }
    }

    /// Returns an immutable pointer to the value at the given slot in the given field.
    ///
    /// - Parameters:
    ///   - field: The field handle identifying which array to access.
    ///   - slot: The physical slot coordinate.
    /// - Returns: An immutable pointer to the value.
    /// - Warning: The caller must ensure the slot is valid and within capacity.
    @unsafe
    @inlinable
    @_disfavoredOverload
    public func pointer<Value: ~Copyable>(
        _ field: Storage.Field<Value>, at slot: Index<Element>
    ) -> UnsafePointer<Value> {
        unsafe UnsafePointer(pointer(field, at: slot))
    }
}
