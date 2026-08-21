import Affine_Primitives_Standard_Library_Integration
public import Index_Primitives
import Ordinal_Primitives_Standard_Library_Integration
public import Store_Protocol_Primitives

extension __StoreProtocol where Self: ~Copyable, Element: Copyable {

    @inlinable
    public func copy<Destination: __StoreProtocol & ~Copyable>(
        to destination: inout Destination,
        count: Index<Element>.Count? = nil
    ) where Destination.Element == Element {

        let limit: Index<Element>.Count = count ?? capacity
        var slot: Index<Element> = .zero
        let upper: Index<Element> = limit.map(Ordinal.init)
        while slot < upper {
            destination.initialize(at: slot, to: self[slot])
            slot += .one
        }
    }
}
