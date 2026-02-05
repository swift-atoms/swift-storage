// StorageLib - Mirrors Storage.Inline structure
// This module is imported by Main to test cross-module deinit behavior

import Synchronization

// Global tracker for deinit calls
public final class DeinitTracker: @unchecked Sendable {
    public let _count = Atomic<Int>(0)
    public var count: Int { _count.load(ordering: .relaxed) }
    public func increment() { _count.wrappingAdd(1, ordering: .relaxed) }
    public func reset() { _count.store(0, ordering: .relaxed) }
    public init() {}
}

// Mirrors Storage<Element>.Inline<capacity> structure
public enum Storage<Element: ~Copyable> {
    public struct Inline<let capacity: Int>: ~Copyable {
        @_rawLayout(likeArrayOf: Element, count: capacity)
        @usableFromInline
        package struct _Raw: ~Copyable {
            @usableFromInline
            init() {}
        }

        @usableFromInline
        package var _storage: _Raw

        @usableFromInline
        package var _count: Int

        // For tracking deinit calls
        @usableFromInline
        package var _tracker: DeinitTracker?

        @inlinable
        public init() {
            _storage = _Raw()
            _count = 0
            _tracker = nil
        }

        @inlinable
        public init(tracker: DeinitTracker) {
            _storage = _Raw()
            _count = 0
            _tracker = tracker
        }

        @inlinable
        public mutating func setCount(_ count: Int) {
            _count = count
        }

        @inlinable
        public mutating func pointer() -> UnsafeMutablePointer<Element> {
            unsafe withUnsafeMutablePointer(to: &_storage) { base in
                let raw = UnsafeMutableRawPointer(base)
                return unsafe raw.assumingMemoryBound(to: Element.self)
            }
        }

        deinit {
            print("Storage.Inline deinit called (count=\(_count))")
            _tracker?.increment()

            // Deinitialize elements
            for i in 0..<_count {
                unsafe withUnsafePointer(to: _storage) { base in
                    let raw = unsafe UnsafeMutableRawPointer(mutating: base)
                    unsafe raw.advanced(by: i * MemoryLayout<Element>.stride)
                        .assumingMemoryBound(to: Element.self)
                        .deinitialize(count: 1)
                }
            }
        }
    }
}

// Sendable conformance
extension Storage.Inline._Raw: @unchecked Sendable where Element: Sendable {}
extension Storage.Inline: @unchecked Sendable where Element: Sendable {}
