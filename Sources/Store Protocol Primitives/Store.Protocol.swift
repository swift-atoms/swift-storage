public import Index_Primitives
public import Store_Primitive

public protocol __StoreProtocol: ~Copyable {

    associatedtype Element: ~Copyable

    var capacity: Index<Element>.Count { get }

    subscript(slot: Index<Element>) -> Element { get set }

    mutating func initialize(at slot: Index<Element>, to element: consuming Element)

    mutating func move(at slot: Index<Element>) -> Element

    mutating func swapAt(_ i: Index<Element>, _ j: Index<Element>)

    mutating func unshare()
}

extension __StoreProtocol where Self: ~Copyable {

    @inlinable
    public mutating func unshare() {}
}

extension __StoreProtocol where Self: ~Copyable {

    @inlinable
    public mutating func swapAt(_ i: Index<Element>, _ j: Index<Element>) {
        guard i != j else { return }
        let a = move(at: i)
        let b = move(at: j)
        initialize(at: i, to: b)
        initialize(at: j, to: a)
    }
}

extension Store {

    public typealias `Protocol` = __StoreProtocol
}
