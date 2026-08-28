# swift-storage

`swift-storage` owns the abstract `Storage<Allocation>` namespace. It deliberately
contains no Store protocols, Store implementations, memory allocation policy, or
umbrella product.

Concrete integrations live in composition packages. In particular,
`swift-storage-memory` supplies `Storage<Allocation>.Contiguous<Element>` because
that implementation semantically depends on the Memory domain.

```swift
.package(url: "https://github.com/swift-atoms/swift-storage.git", branch: "main")
```

```swift
.product(name: "Storage", package: "swift-storage")
```

`swift-storage` and `swift-store` do not depend on one another. A package that
combines the domains declares both dependencies explicitly.

Apache 2.0. See [LICENSE.md](LICENSE.md).
