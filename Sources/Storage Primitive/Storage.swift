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

/// Namespace for storage primitives.
///
/// `Storage` provides storage disciplines with different lifecycle contracts:
///
/// | Need | Choose | Lifecycle |
/// |------|--------|-----------|
/// | Automatic cleanup, contiguous elements | `Storage.Heap` | **Tracked** — range-based initialization tracking with automatic cleanup in `deinit` |
/// | Stack-allocated, fixed capacity ≤256 | `Storage.Inline` | **Auto-tracked** — per-slot bit-vector tracking; consumer responsible for cleanup |
/// | Dual-array with consumer-defined metadata | `Storage.Split` | **Metadata-driven** — no tracking; consumer interprets lane metadata to determine element validity |
/// | Pool allocation with per-slot reuse | `Storage.Pool` | **Bitmap-tracked** — per-slot bit-vector tracking with automatic cleanup in `deinit` |
///
/// Each discipline is its own sibling package; see `Storage Primitives Scope.md`.
public enum Storage<Element: ~Copyable> {}
