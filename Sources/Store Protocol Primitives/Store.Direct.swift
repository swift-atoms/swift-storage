@_documentation(visibility: public)
public protocol __ColumnDirect: __StoreProtocol, ~Copyable {

    associatedtype Bounded: ~Copyable
}

extension Store {

    public typealias Direct = __ColumnDirect
}
