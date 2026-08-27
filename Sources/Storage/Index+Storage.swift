public import Cardinal
public import Index
public import Ordinal
public import Tagged

extension Tagged where Tag: ~Copyable & ~Escapable, Underlying == Ordinal {

    public typealias Count = Tagged<Tag, Cardinal>
}

extension Tagged where Tag: ~Copyable & ~Escapable, Underlying == Ordinal {

    @inlinable
    public init(_ value: UInt) {
        self.init(_unchecked: Ordinal(value))
    }

    @inlinable
    public init(_ count: borrowing Tagged<Tag, Cardinal>) {
        self.init(_unchecked: Ordinal(count.underlying.rawValue))
    }

    @inlinable
    public var rawValue: UInt { underlying.rawValue }

    @inlinable
    public static var zero: Self { Self(UInt.zero) }
}

extension Tagged where Tag: ~Copyable & ~Escapable, Underlying == Ordinal {

    @inlinable
    public static func == (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
        lhs.underlying == rhs.underlying
    }

    @inlinable
    public static func != (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
        !(lhs.underlying == rhs.underlying)
    }

    @inlinable
    public static func < (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
        lhs.underlying < rhs.underlying
    }

    @inlinable
    public static func <= (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
        lhs.underlying <= rhs.underlying
    }

    @inlinable
    public static func > (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
        lhs.underlying > rhs.underlying
    }

    @inlinable
    public static func >= (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
        lhs.underlying >= rhs.underlying
    }
}

extension Tagged where Tag: ~Copyable & ~Escapable, Underlying == Ordinal {

    @inlinable
    public func advanced(by count: borrowing Tagged<Tag, Cardinal>) -> Self {
        let (result, overflow) = rawValue.addingReportingOverflow(count.rawValue)
        precondition(!overflow, "Storage slot overflow in advance")
        return Self(result)
    }

    @inlinable
    public static func += (slot: inout Self, count: borrowing Tagged<Tag, Cardinal>) {
        slot = slot.advanced(by: count)
    }
}

extension Tagged where Tag: ~Copyable & ~Escapable, Underlying == Cardinal {

    @inlinable
    public init(_ value: UInt) {
        self.init(_unchecked: Cardinal(value))
    }

    @inlinable
    public init(_ slot: borrowing Tagged<Tag, Ordinal>) {
        self.init(_unchecked: Cardinal(slot.underlying.rawValue))
    }

    @inlinable
    public var rawValue: UInt { underlying.rawValue }

    @inlinable
    public static var zero: Self { Self(UInt.zero) }

    @inlinable
    public static var one: Self { Self(1) }
}

extension Tagged where Tag: ~Copyable & ~Escapable, Underlying == Cardinal {

    @inlinable
    public static func == (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
        lhs.underlying == rhs.underlying
    }

    @inlinable
    public static func != (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
        !(lhs.underlying == rhs.underlying)
    }

    @inlinable
    public static func < (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
        lhs.underlying < rhs.underlying
    }

    @inlinable
    public static func <= (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
        lhs.underlying <= rhs.underlying
    }

    @inlinable
    public static func > (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
        lhs.underlying > rhs.underlying
    }

    @inlinable
    public static func >= (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
        lhs.underlying >= rhs.underlying
    }
}

extension Tagged where Tag: ~Copyable & ~Escapable, Underlying == Cardinal {

    @inlinable
    public static func + (lhs: borrowing Self, rhs: borrowing Self) -> Self {
        Self(_unchecked: lhs.underlying + rhs.underlying)
    }

    @inlinable
    public func adding(saturating other: borrowing Self) -> Self {
        let (result, overflow) = rawValue.addingReportingOverflow(other.rawValue)
        return Self(overflow ? UInt.max : result)
    }

    @inlinable
    public func subtracting(saturating other: borrowing Self) -> Self {
        let (result, overflow) = rawValue.subtractingReportingOverflow(other.rawValue)
        return Self(overflow ? UInt.zero : result)
    }
}
