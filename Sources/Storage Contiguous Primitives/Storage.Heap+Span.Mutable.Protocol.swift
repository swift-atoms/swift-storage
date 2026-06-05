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
public import Span_Protocol_Primitives
public import Storage_Primitive

// MARK: - Span.Mutable.Protocol Conformance (pinned to the heap composition)

// The concrete mutable-span capability (#12b) on the COMPOSED type, relocated
// by the storage/memory split: the leaf (`Memory.Heap`) carries its own
// conformance; this pinned conditional conformance restores the capability to
// `Storage<E>.Contiguous<Memory.Heap<E>>` (= `Contiguous<Memory.Heap<E>>`). Both witnesses are
// present at this pin — `span` via the generic Substrate-vends-Span
// conditional conformance, `mutableSpan` via the pinned forwarder
// (Storage.Contiguous<Memory.Heap<Element>>+Span.swift) — and the chain is concrete end-to-end, which is
// what keeps it OUTSIDE the structural no-generic-`mutableSpan` wall (the
// MutableSpan-never-a-generic-seam gate; a `Substrate: Span.Mutable`-generic
// conformance would be exactly the walled form-G shape and is deliberately
// NOT declared).
extension Storage.Contiguous: Span.Mutable.`Protocol` where Element: ~Copyable, Substrate == Memory.Heap<Element> {}
