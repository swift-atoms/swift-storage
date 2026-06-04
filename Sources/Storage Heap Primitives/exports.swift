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

// The storage/memory split SHIM (storage-memory-split.md, seat-ratified
// 2026-06-04): `Storage<E>.Heap` is now the typealias
// `Storage<E>.Contiguous<Memory.Heap<E>>` (declared in Storage Contiguous
// Primitives); the heap MECHANICS live in swift-memory-heap-primitives.
// This target keeps `import Storage_Heap_Primitives` source-stable by
// re-exporting the composed surface and everything the fused target
// re-exported.

@_exported public import Memory_Heap_Primitives
@_exported public import Property_Primitives
@_exported public import Storage_Accessor_Primitives
@_exported public import Storage_Contiguous_Primitives
@_exported public import Storage_Error_Primitives
@_exported public import Storage_Initialization_Primitives
@_exported public import Storage_Primitive
