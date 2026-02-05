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
public import Standard_Library_Extensions

// MARK: - Copyable Extensions

extension Storage.Heap where Element: Copyable {
    /// Creates a copy of this storage with all initialized elements.
    ///
    /// Handles all initialization patterns (.empty, .one, .two).
    ///
    /// - Returns: A new storage instance with copied elements.
    @inlinable
    public func copy() -> Storage.Heap<Element> {
        let init_ = self.initialization
        let count = init_.count
        let new = Storage.Heap<Element>.create(minimumCapacity: count)
        new.initialization = .linear(count: count)

        guard count > .zero else { return new }

        func copySpan(_ range: Swift.Range<Index<Storage>>, dstStart: inout Index<Storage>) {
            guard !range.isEmpty else { return }
            _ = unsafe withUnsafeMutablePointerToElements { src in
                unsafe new.withUnsafeMutablePointerToElements { dst in
                    var slot = range.lowerBound
                    while slot < range.upperBound {
                        let srcOffset = Index<Storage>.Offset(fromZero: slot).retag(Element.self)
                        let dstOffset = Index<Storage>.Offset(fromZero: dstStart).retag(Element.self)
                        unsafe (dst + dstOffset).initialize(to: (src + srcOffset).pointee)
                        slot = slot.successor.saturating()
                        dstStart = dstStart.successor.saturating()
                    }
                }
            }
        }

        var dstSlot: Index<Storage> = .zero
        switch init_ {
        case .empty:
            break
        case .one(let range):
            copySpan(range, dstStart: &dstSlot)
        case .two(let first, let second):
            copySpan(first, dstStart: &dstSlot)
            copySpan(second, dstStart: &dstSlot)
        }

        return new
    }

    /// Copies all initialized elements to destination storage.
    ///
    /// Elements are copied to linear positions starting at slot 0 in the destination.
    /// Handles all initialization patterns (.empty, .one, .two).
    ///
    /// - Parameter destination: The destination storage.
    /// - Precondition: Destination must have sufficient capacity.
    @inlinable
    public func copy(to destination: Storage.Heap<Element>) {
        let init_ = self.initialization

        func copySpan(_ range: Swift.Range<Index<Storage>>, dstStart: inout Index<Storage>) {
            guard !range.isEmpty else { return }
            _ = unsafe withUnsafeMutablePointerToElements { src in
                unsafe destination.withUnsafeMutablePointerToElements { dst in
                    var slot = range.lowerBound
                    while slot < range.upperBound {
                        let srcOffset = Index<Storage>.Offset(fromZero: slot).retag(Element.self)
                        let dstOffset = Index<Storage>.Offset(fromZero: dstStart).retag(Element.self)
                        unsafe (dst + dstOffset).initialize(to: (src + srcOffset).pointee)
                        slot = slot.successor.saturating()
                        dstStart = dstStart.successor.saturating()
                    }
                }
            }
        }

        var dstSlot: Index<Storage> = .zero
        switch init_ {
        case .empty:
            break
        case .one(let range):
            copySpan(range, dstStart: &dstSlot)
        case .two(let first, let second):
            copySpan(first, dstStart: &dstSlot)
            copySpan(second, dstStart: &dstSlot)
        }
    }

    /// Copies elements in the given range to linear positions in the destination.
    ///
    /// Elements from the source range are placed at slots 0..<range.count in the
    /// destination storage.
    ///
    /// - Parameters:
    ///   - range: The contiguous range of slots to copy from.
    ///   - destination: The destination storage.
    /// - Precondition: All slots in the range must contain initialized elements.
    /// - Precondition: Destination slots 0..<range.count must be uninitialized.
    @inlinable
    public func copy(range: Swift.Range<Index<Storage>>, to destination: Storage.Heap<Element>) {
        guard !range.isEmpty else { return }
        _ = unsafe withUnsafeMutablePointerToElements { src in
            unsafe destination.withUnsafeMutablePointerToElements { dst in
                var srcSlot = range.lowerBound
                var dstSlot: Index<Storage> = .zero
                while srcSlot < range.upperBound {
                    let srcOffset = Index<Storage>.Offset(fromZero: srcSlot).retag(Element.self)
                    let dstOffset = Index<Storage>.Offset(fromZero: dstSlot).retag(Element.self)
                    unsafe (dst + dstOffset).initialize(to: (src + srcOffset).pointee)
                    srcSlot = srcSlot.successor.saturating()
                    dstSlot = dstSlot.successor.saturating()
                }
            }
        }
    }
}
