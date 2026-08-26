public import Index
public import Store_Primitive

extension Store {

    public enum Initialization<Element: ~Copyable & ~Escapable>: Sendable, Equatable {

        case empty

        case one(Swift.Range<Index.Index<Element>>)

        case two(
            first: Swift.Range<Index.Index<Element>>,
            second: Swift.Range<Index.Index<Element>>
        )
    }
}
