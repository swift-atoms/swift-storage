public import Index

extension Store {

    public enum Initialization<Element: ~Copyable & ~Escapable>: Sendable, Equatable {

        case empty

        case one(Store.Span<Element>)

        case two(
            first: Store.Span<Element>,
            second: Store.Span<Element>
        )
    }
}
