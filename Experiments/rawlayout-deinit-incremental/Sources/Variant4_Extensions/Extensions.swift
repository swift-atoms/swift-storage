// MARK: - Variant 4: Extensions Module
// Re-exports Core and adds extension methods

public import Variant4_Core

extension Storage.Inline where Element: ~Copyable {
    @inlinable
    public var initialization: Storage<Element>.Initialization {
        get { _initialization }
        set { _initialization = newValue }
    }

    @inlinable
    public mutating func pointer() -> UnsafeMutablePointer<Element> {
        unsafe withUnsafeMutablePointer(to: &_storage) { base in
            let raw = UnsafeMutableRawPointer(base)
            return unsafe raw.assumingMemoryBound(to: Element.self)
        }
    }

    @inlinable
    public mutating func initialize(to element: consuming Element, at slot: Index<Element>) {
        let ptr = unsafe pointer()
        unsafe (ptr + slot.rawValue).initialize(to: element)
    }
}

extension Storage.Initialization where Element: ~Copyable {
    @inlinable
    public static func linear(count: Int) -> Self {
        guard count > 0 else { return .empty }
        return .one(Index<Element>.zero ..< Index<Element>(count))
    }
}
