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
public import Index_Primitives

// MARK: - Copyable Extensions

extension Storage.Heap where Element: Copyable {
    /// Creates a copy of this storage with all elements.
    ///
    /// - Returns: A new storage instance with copied elements.
    @inlinable
    public func copy() -> Storage.Heap<Element> {
        let count = self.initialization.count
        let countInt = Int(bitPattern: count)

        let new = unsafe unsafeDowncast(
            Storage.Heap<Element>.create(minimumCapacity: countInt) { _ in
                Storage.Header(initialization: .linear(count: Storage.Slot.Count(UInt(countInt))))
            },
            to: Storage.Heap<Element>.self
        )

        guard count > .zero else { return new }

        _ = unsafe withUnsafeMutablePointerToElements { src in
            unsafe new.withUnsafeMutablePointerToElements { dst in
                (.zero..<count).forEach { index in
                    let offset = Int(bitPattern: index.rawValue.rawValue)
                    unsafe (dst + offset).initialize(to: src[offset])
                }
            }
        }

        return new
    }

    /// Copies all initialized elements to a new storage instance.
    ///
    /// - Parameter newStorage: The destination storage.
    /// - Precondition: Elements at indices 0..<count must be initialized in this storage.
    /// - Precondition: Elements at indices 0..<count must be uninitialized in newStorage.
    @inlinable
    public func copy(to newStorage: Storage.Heap<Element>) {
        let count = self.initialization.count
        guard count > .zero else { return }
        _ = unsafe withUnsafeMutablePointerToElements { src in
            unsafe newStorage.withUnsafeMutablePointerToElements { dst in
                (.zero..<count).forEach { index in
                    let offset = Int(bitPattern: index.rawValue.rawValue)
                    unsafe (dst + offset).initialize(to: src[offset])
                }
            }
        }
    }
}
