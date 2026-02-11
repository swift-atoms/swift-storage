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
public import Bit_Vector_Primitives

// MARK: - CoW Copy

extension Storage.Pool where Element: Copyable {
    /// Creates a deep copy of this pool for copy-on-write.
    ///
    /// Copies all allocated elements to a new pool with identical slot layout.
    /// Free list structure and virgin cursor state are preserved, ensuring
    /// that `Index<Element>` values remain valid in the copy.
    ///
    /// - Returns: A new pool with the same capacity, allocation state, and element values.
    @inlinable
    public func copy() -> Storage.Pool {
        let newStorage = UnsafeMutablePointer<Element>.allocate(
            capacity: Int(bitPattern: _capacity)
        )

        let newBits = Bit.Vector(capacity: _capacity.retag(Bit.self))

        // Copy used region (bounded by virgin cursor).
        var slot: Index<Element> = .zero
        while slot < _nextUnused {
            let bitIndex = slot.retag(Bit.self)
            let offset = Index<Element>.Offset(fromZero: slot)
            if _allocationBits[bitIndex] {
                // Allocated slot: copy element.
                unsafe (newStorage + offset).initialize(
                    to: (_storage + offset).pointee
                )
                newBits[bitIndex] = true
            } else {
                // Freed slot: copy in-band free list link.
                let src = unsafe UnsafeMutableRawPointer(_storage + offset)
                let link = unsafe src.load(as: Index<Element>.self)
                unsafe UnsafeMutableRawPointer(newStorage + offset)
                    .storeBytes(of: link, as: Index<Element>.self)
            }
            slot = slot + .one
        }

        return unsafe Storage.Pool(
            _copying: newStorage,
            capacity: _capacity,
            allocated: _allocated,
            freeHead: _freeHead,
            nextUnused: _nextUnused,
            allocationBits: newBits
        )
    }
}
