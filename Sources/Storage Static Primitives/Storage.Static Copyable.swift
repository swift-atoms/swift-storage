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

// MARK: - Copyable Extensions for Inline Storage

extension Storage.Static where Element: Copyable {
    /// Copies elements from this inline storage to heap storage.
    ///
    /// - Parameters:
    ///   - heapStorage: The destination heap storage.
    ///   - count: The number of elements to copy.
    /// - Precondition: Elements at indices 0..<count must be initialized in this storage.
    /// - Precondition: Elements at indices 0..<count must be uninitialized in heapStorage.
    @inlinable
    public func copy(to heapStorage: Storage<Element>, count: Index<Element>.Count) {
        guard count > .zero else { return }
        _ = unsafe withUnsafePointer(to: _storage) { base in
            let address = unsafe Memory.Address(base)
            unsafe heapStorage.withUnsafeMutablePointerToElements { dst in
                (.zero..<count).forEach { index in
                    let src = address.pointer(at: index, stride: Self.slotStride, as: Element.self)
                    unsafe (dst + index).initialize(to: src.pointee)
                }
            }
        }
    }
}
