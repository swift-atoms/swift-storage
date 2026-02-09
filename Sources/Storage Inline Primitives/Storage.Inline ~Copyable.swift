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
internal import Vector_Primitives

// MARK: - Properties

extension Storage.Inline where Element: ~Copyable {
    /// Storage capacity in slot count.
    ///
    /// This is a runtime-accessible view of the compile-time `capacity` parameter.
    /// Matches `Storage.Heap.slotCapacity` for API parity.
    @inlinable
    public var slotCapacity: Index<Element>.Count {
        Index<Element>.Count(Cardinal(UInt(capacity)))
    }

    /// Initialization state derived from the bit vector.
    ///
    /// The getter assumes linear initialization discipline (contiguous from slot 0).
    /// It returns `.linear(count: popcount)` where `popcount` is the number of
    /// set bits. This is correct when all initialized slots form a contiguous
    /// range starting at zero.
    ///
    /// For sparse or ring buffer patterns set via the setter, the getter is
    /// lossy — it reports the total count but not the actual slot positions.
    /// For per-slot tracking in those cases, inspect `_slots` directly.
    ///
    /// The setter correctly handles all patterns (`.empty`, `.one`, `.two`)
    /// by updating the bit vector ranges. This allows buffer-primitives to
    /// sync header state with storage via
    /// `storage.initialization = header.initialization`.
    @inlinable
    public var initialization: Storage.Initialization {
        get {
            if _slots.isEmpty {
                return .empty
            }
            // For linear patterns, compute the range from 0 to count
            let count = _slots.popcount.retag(Element.self)
            return .linear(count: count)
        }
        set {
            _slots.clear.all()
            newValue.forEach { range in
                guard !range.isEmpty else { return }
                _slots.set.range(range.map.bounds { $0.retag(Bit.self) })
            }
        }
    }
}

