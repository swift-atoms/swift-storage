public import Store_Initialization_Primitives
public import Store_Primitive
public import Store_Protocol_Primitives

public protocol __StoreLedgeredProtocol: Store.`Protocol`, ~Copyable {

    var initialization: Store.Initialization<Element> { get set }
}

extension Store {

    public enum Ledgered {}
}

extension Store.Ledgered {

    public typealias `Protocol` = __StoreLedgeredProtocol
}
