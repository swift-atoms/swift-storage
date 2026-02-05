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

extension Storage.Inline where Element: Copyable {
    /// Copies elements in range to linear positions in destination heap storage.
    ///
    /// Elements from the source range are placed at slots 0..<range.count in the
    /// destination storage.
    ///
    /// - Parameters:
    ///   - range: The contiguous range of slots to copy from.
    ///   - destination: The destination heap storage.
    /// - Precondition: All slots in the range must contain initialized elements.
    /// - Precondition: Destination slots 0..<range.count must be uninitialized.
    @inlinable
    public func copy(range: Swift.Range<Index<Storage>>, to destination: Storage.Heap<Element>) {
        guard !range.isEmpty else { return }
        let count = Int(range.count.rawValue.rawValue)
        let srcPtr = unsafe pointer(at: range.lowerBound)
        unsafe destination.withUnsafeMutablePointerToElements { dst in
            unsafe dst.initialize(from: srcPtr, count: count)
        }
    }
}
