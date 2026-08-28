public import Storage_Primitive

@_documentation(visibility: public)
public enum __StorageContiguousError: Swift.Error, Sendable, Equatable {

    case overflow(capacity: Int, stride: Int)
}

extension Storage.Contiguous where Allocation: ~Copyable, Element: ~Copyable {

    public typealias Error = __StorageContiguousError
}
