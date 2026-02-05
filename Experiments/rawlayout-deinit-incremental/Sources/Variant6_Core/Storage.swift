// MARK: - Variant 6: Core Module with Real Index_Primitives
// This uses the actual external Index_Primitives package

public import Synchronization
public import Index_Primitives

public final class DeinitTracker: @unchecked Sendable {
    public let _count = Atomic<Int>(0)
    public var count: Int { _count.load(ordering: .relaxed) }
    public func increment() { _count.wrappingAdd(1, ordering: .relaxed) }
    public func reset() { _count.store(0, ordering: .relaxed) }
    public init() {}
}

public enum Storage<Element: ~Copyable> {

    /// Initialization state - uses real Index<Element> from Index_Primitives
    public enum Initialization: Sendable, Equatable {
        case empty
        case one(Swift.Range<Index_Primitives.Index<Element>>)
        case two(first: Swift.Range<Index_Primitives.Index<Element>>, second: Swift.Range<Index_Primitives.Index<Element>>)
    }

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
        package var _initialization: Initialization

        @usableFromInline
        package var _tracker: DeinitTracker?

        @inlinable
        public init() {
            _storage = _Raw()
            _initialization = .empty
            _tracker = nil
        }

        @inlinable
        public init(tracker: DeinitTracker) {
            _storage = _Raw()
            _initialization = .empty
            _tracker = tracker
        }

        /// Deinitializes all elements in the given range.
        @inlinable
        public func deinitialize(range: Swift.Range<Index<Element>>) {
            guard !range.isEmpty else { return }
            _ = unsafe withUnsafePointer(to: _storage) { base in
                let raw = unsafe UnsafeMutableRawPointer(mutating: base)
                let startPtr = unsafe raw
                    .advanced(by: Int(range.lowerBound.rawValue.rawValue) * MemoryLayout<Element>.stride)
                    .assumingMemoryBound(to: Element.self)
                unsafe startPtr.deinitialize(count: Int(range.count.rawValue.rawValue))
            }
        }

        /// Deinitializes all tracked initialized slots.
        @inlinable
        package func deinitialize() {
            switch _initialization {
            case .empty:
                return
            case .one(let range):
                deinitialize(range: range)
            case .two(let first, let second):
                deinitialize(range: first)
                deinitialize(range: second)
            }
        }

        deinit {
            print("Variant6 Storage.Inline deinit called")
            _tracker?.increment()
            self.deinitialize()
        }
    }

    /// Placeholder for Heap storage
    public final class Heap {
        public init() {}
    }
}

extension Storage.Inline._Raw: @unchecked Sendable where Element: Sendable {}
extension Storage.Inline: @unchecked Sendable where Element: Sendable {}
