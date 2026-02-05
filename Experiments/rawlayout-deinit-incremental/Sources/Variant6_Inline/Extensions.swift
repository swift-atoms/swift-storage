// MARK: - Variant 6: Inline Extensions Module
// Re-exports Core and adds extensions - uses real Index_Primitives

public import Variant6_Core
public import Index_Primitives

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
    public mutating func pointer(at slot: Index<Element>) -> UnsafeMutablePointer<Element> {
        unsafe withUnsafeMutablePointer(to: &_storage) { base in
            let raw = UnsafeMutableRawPointer(base)
            return unsafe raw.advanced(by: Int(slot.rawValue.rawValue) * MemoryLayout<Element>.stride)
                .assumingMemoryBound(to: Element.self)
        }
    }

    @inlinable
    public mutating func initialize(to element: consuming Element, at slot: Index<Element>) {
        unsafe pointer(at: slot).initialize(to: element)
    }

    @inlinable
    public mutating func move(at slot: Index<Element>) -> Element {
        unsafe pointer(at: slot).move()
    }
}

extension Storage.Initialization where Element: ~Copyable {
    @inlinable
    public static func linear(count: Index<Element>.Count) -> Self {
        guard count > .zero else { return .empty }
        return .one(Swift.Range<Index<Element>>(start: .zero, count: count))
    }
}
