public import Index
public import Ordinal
public import Tagged

@inlinable
@unsafe
public func + <Element: ~Copyable>(
    base: UnsafePointer<Element>,
    slot: borrowing Tagged<Element, Ordinal>
) -> UnsafePointer<Element> {
    unsafe base + Int(bitPattern: slot.underlying.rawValue)
}

@inlinable
@unsafe
public func + <Element: ~Copyable>(
    base: UnsafeMutablePointer<Element>,
    slot: borrowing Tagged<Element, Ordinal>
) -> UnsafeMutablePointer<Element> {
    unsafe base + Int(bitPattern: slot.underlying.rawValue)
}
