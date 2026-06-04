// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Storage_Primitive
public import Store_Initialization_Primitives

extension Storage where Element: ~Copyable {
    /// The initialization ledger — the storage-tier spelling of
    /// ``Store/Initialization``.
    ///
    /// The canonical declaration relocated to `swift-store-primitives` by the
    /// storage/memory split (`swift-institute/Research/storage-memory-split.md`
    /// §2, seat-ratified 2026-06-04): the `Memory.Heap` leaf vends the ledger
    /// and must sit below the storage tier, so the type does too. This
    /// typealias keeps every `Storage<Element>.Initialization` spelling — and
    /// every `import Storage_Initialization_Primitives` — source-stable.
    public typealias Initialization = Store.Initialization<Element>
}
