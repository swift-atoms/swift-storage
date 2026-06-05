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

// NOTE (Cleave-5): the `Storage.Protocol` single-region marker was dissolved
// (Storage.Contiguous<M> is single-region by construction). This target now hosts
// the single-region lifecycle derivations as `extension Store.Protocol` (pure
// 4-op seam — deinitialize / fill / move / copy / forEach), shared by every
// Store.Protocol conformer (the leaves, Storage.Contiguous, and the topology
// disciplines).
@_exported public import Index_Primitives
@_exported public import Store_Protocol_Primitives
