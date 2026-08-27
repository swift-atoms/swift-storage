
public protocol __StoreLedgeredProtocol: Store.`Protocol`, ~Copyable {

    var initialization: Store.Initialization<Element> { get set }
}

extension Store {

    public enum Ledgered {}
}

extension Store.Ledgered {

    public typealias `Protocol` = __StoreLedgeredProtocol
}
