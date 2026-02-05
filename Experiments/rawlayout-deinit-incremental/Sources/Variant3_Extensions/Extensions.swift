// MARK: - Variant 3: Extensions Module with Full SwiftSettings
// Re-exports Core and adds extension methods

public import Variant3_Core

extension Storage.Inline where Element: ~Copyable {
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
}
