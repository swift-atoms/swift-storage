import Index

extension Store {

    @frozen
    public struct Inline<Element: ~Copyable, let n: Int>: ~Copyable {

        @usableFromInline
        internal var _deinitWorkaround: AnyObject? = nil

        @usableFromInline
        internal var _initialization: Store.Initialization<Element>

        @_rawLayout(likeArrayOf: Element, count: n)
        @usableFromInline
        internal struct _Raw: ~Copyable {
            @usableFromInline
            internal init() {}
        }

        @usableFromInline
        internal var _storage: _Raw

        @inlinable
        public init() {
            self._deinitWorkaround = nil
            self._initialization = .empty
            self._storage = _Raw()
        }

        deinit {
            _initialization.forEach { range in
                guard !range.isEmpty else { return }
                withUnsafePointer(to: _storage) { raw in
                    let base = unsafe UnsafeMutableRawPointer(mutating: UnsafeRawPointer(raw))
                        .assumingMemoryBound(to: Element.self)
                    unsafe (base + range.lowerBound)
                        .deinitialize(count: Int(bitPattern: range.count.rawValue))
                }
            }
        }
    }
}
