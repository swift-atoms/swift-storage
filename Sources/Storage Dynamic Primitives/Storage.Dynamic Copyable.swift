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

// MARK: - Copyable Extensions

extension Storage where Element: Copyable {
    /// Creates a copy of this storage with all elements.
    ///
    /// - Returns: A new storage instance with copied elements.
    @inlinable
    public func copy() -> Storage<Element> {
        let count = self.count
        let countInt = Int(bitPattern: count)

        let new = unsafe unsafeDowncast(
            Storage<Element>.create(minimumCapacity: countInt) { _ in countInt },
            to: Storage<Element>.self
        )

        guard count > .zero else { return new }

        _ = unsafe withUnsafeMutablePointerToElements { src in
            unsafe new.withUnsafeMutablePointerToElements { dst in
                (.zero..<count).forEach { index in
                    let offset = Index.Offset(__unchecked: (), index)
                    unsafe (dst + offset).initialize(to: src[index])
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
    public func copy(to newStorage: Storage<Element>) {
        let count = self.count
        guard count > .zero else { return }
        _ = unsafe withUnsafeMutablePointerToElements { src in
            unsafe newStorage.withUnsafeMutablePointerToElements { dst in
                (.zero..<count).forEach { index in
                    let offset = Index.Offset(__unchecked: (), index)
                    unsafe (dst + offset).initialize(to: src[index])
                }
            }
        }
    }
}
