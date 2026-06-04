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

public import Memory_Heap_Primitives
public import Storage_Primitive

extension Storage where Element: ~Copyable {
    /// Canonical heap storage — the Storage discipline composed over the heap
    /// allocation-strategy leaf.
    ///
    /// `Storage<Element>.Heap` is, post-split, EXACTLY
    /// `Storage<Element>.Contiguous<Memory.Heap<Element>>`: the single-region
    /// storage discipline (`Storage.Contiguous`) lifted over the class-backed
    /// heap leaf (`Memory.Heap`), whose backing-class `deinit` is the cleanup
    /// oracle for the `Store.Initialization` ledger the discipline syncs.
    ///
    /// The typealias is the source-stability seam of the storage/memory split
    /// (`swift-institute/Research/storage-memory-split.md`, seat-ratified
    /// 2026-06-04): every existing spelling — `Storage<E>.Heap` in type
    /// positions, `S == Storage<E>.Heap` same-type pins, the pinned creation
    /// paths and CoW probes — resolves through it unchanged. The truthful
    /// composed spelling (`Buffer<Storage<E>.Contiguous<Memory.Heap<E>>>.Ring`)
    /// becomes available to the later coherence pass (#5a(i)); this spelling
    /// remains the sanctioned intermediate.
    public typealias Heap = Storage<Element>.Contiguous<Memory.Heap<Element>>
}
