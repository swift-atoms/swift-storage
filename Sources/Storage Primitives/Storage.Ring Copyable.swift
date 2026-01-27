//
//  File.swift
//  swift-storage-primitives
//
//  Created by Coen ten Thije Boonkkamp on 27/01/2026.
//

// MARK: - Copyable Ring Operations

extension Storage.Ring where Element: Copyable {
    /// Copies elements from a ring buffer to linear storage.
    ///
    /// Non-destructive variant. Source pointer immutability distinguishes
    /// this overload from the move variant.
    ///
    /// - Parameters:
    ///   - source: Immutable pointer to source ring buffer elements.
    ///   - head: Physical index of first element in ring.
    ///   - count: Number of elements to copy.
    ///   - capacity: Source buffer capacity (for wrapping).
    ///   - destination: Pointer to destination (linear, starting at 0).
    @inlinable
    public static func linearize(
        from source: Pointer<Element>,
        head: Index<Element>,
        count: Index<Element>.Count,
        capacity: Index<Element>.Count,
        to destination: Pointer<Element>.Mutable
    ) {
        guard count > .zero else { return }
        var srcIndex = head
        (.zero..<count).forEach { dstIndex in
            unsafe (destination.base + dstIndex).initialize(
                to: (source.base + srcIndex).pointee
            )
            srcIndex = successor(of: srcIndex, wrapping: capacity)
        }
    }
}
