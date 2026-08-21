public import Index_Primitives
public import Store_Primitive

extension Store {

    public enum Initialization<Element: ~Copyable & ~Escapable>: Sendable, Equatable {

        case empty

        case one(Swift.Range<Index_Primitives.Index<Element>>)

        case two(
            first: Swift.Range<Index_Primitives.Index<Element>>,
            second: Swift.Range<Index_Primitives.Index<Element>>
        )
    }
}
