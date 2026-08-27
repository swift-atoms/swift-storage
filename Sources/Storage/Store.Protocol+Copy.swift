public import Index

extension __StoreProtocol where Self: ~Copyable, Element: Copyable {

    @inlinable
    public func copy<Destination: __StoreProtocol & ~Copyable>(
        to destination: inout Destination,
        count: Index<Element>.Count? = nil
    ) where Destination.Element == Element {

        let limit: Index<Element>.Count = count ?? capacity
        var slot: Index<Element> = .zero
        let upper = Index<Element>(limit)
        while slot < upper {
            destination.initialize(at: slot, to: self[slot])
            slot += .one
        }
    }
}
