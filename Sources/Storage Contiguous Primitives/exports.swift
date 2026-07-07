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

// Re-export the namespace + the element-free allocator/heap tier + the seam/ledger, so a consumer
// spelling `Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Element>` gets every token by
// importing this one module.

@_exported public import Memory_Allocator_Primitive
@_exported public import Memory_Heap_Primitives
@_exported public import Storage_Primitive
@_exported public import Store_Initialization_Primitives
@_exported public import Store_Protocol_Primitives
