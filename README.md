# Storage

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)
[![CI](https://github.com/swift/swift-storage/actions/workflows/ci.yml/badge.svg)](https://github.com/swift/swift-storage/actions/workflows/ci.yml)

`Storage<Element>` — a low-level, manually-managed storage substrate: typed slots you `initialize`, `move`, and `deinitialize` by index, in two canonical forms behind one protocol. **`Storage.Heap`** is heap-backed and growable; **`Storage.Inline<N>`** is fixed-capacity inline storage with no heap allocation.

This is the layer *beneath* collections — the thing you build a `Vector`, `Deque`, or ring buffer on top of. There's no automatic memory management and no implicit copying: you own each slot's initialization state, and `Element` may be `~Copyable`. The `Storage.Protocol` discipline (`initialize` / `move` / `deinitialize` / `fill`, plus slot tracking via `Storage.Initialization`) is shared across both forms, so an algorithm written against the protocol works on either backing.

---

## Key Features

- **Two storage forms, one protocol** — `Storage.Heap` (heap-backed, growable) and `Storage.Inline<N>` (inline, fixed capacity, no heap) both satisfy `Storage.Protocol`, so code can be generic over the backing.
- **Manual slot lifecycle** — `initialize`, `move` (moves the element out), and `deinitialize` give precise, copy-free control; `Storage.Initialization` tracks which slots are live so `count` / `isEmpty` stay honest.
- **`~Copyable` elements** — slots hold move-only elements without forcing a copy; `move` transfers ownership out of the slot.
- **Typed indexing** — slots are addressed by typed `Index` / `Finite.Bounded` positions rather than bare `Int`, and layout facts come from `swift-memory`.

---

## Quick Start

Inline, fixed-capacity storage — lives entirely in the value, no heap:

```swift
import Storage

var inline = Storage<Int>.Inline<8>()
inline.initialize(to: 42, at: 0)
inline.initialization.count   // 1
let x = inline.move(at: 0)    // 42 — moves the element out of the slot
inline.isEmpty                // true
```

Heap-backed storage — created with a minimum capacity, grows as needed:

```swift
var heap = Storage<Int>.Heap.create(minimumCapacity: 10)
let slot = try heap.initialize.next(to: 42)   // initializes the next free slot
heap.initialization.count                       // 1
let y = try heap.move.last()                    // 42 — moves the last element out
heap.isEmpty                                     // true
```

---

## Installation

Add the dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/swift/swift-storage.git", branch: "main")
]
```

Add the umbrella product to your target:

```swift
.target(
    name: "App",
    dependencies: [
        .product(name: "Storage", package: "swift-storage")
    ]
)
```

Or depend on a narrower product (e.g. `Storage Heap`, `Storage Inline`, or `Storage Protocol` for just the discipline) — see Architecture.

Requires Swift 6.3.1 and macOS 26 / iOS 26 / tvOS 26 / watchOS 26 / visionOS 26 (or the corresponding Linux / Windows toolchain).

---

## Architecture

| Product | Contents | When to import |
|---------|----------|----------------|
| `Storage` | Umbrella — re-exports every sub-namespace below | Most consumers |
| `Storage Heap` | `Storage.Heap` — heap-backed, growable storage | Dynamic / unknown size |
| `Storage Inline` | `Storage.Inline<N>` — fixed-capacity inline storage | Small fixed capacity, no heap |
| `Storage Protocol` | `Storage.Protocol` — the shared initialize/move/deinitialize discipline | Writing code generic over the backing |
| `Storage Initialization` | `Storage.Initialization` — live-slot tracking | Custom storage conformers |
| `Storage Field` | `Storage.Field` — physical layout truth (slots, capacity) | Custom storage conformers |
| `Storage Accessor` / `Storage Error` | Accessor tags and the typed error surface | Transitive |
| `Storage Test Support` | Re-exports for downstream test targets | Test target only |

---

## Platform Support

| Platform         | CI  | Status       |
|------------------|-----|--------------|
| macOS 26         | Yes | Full support |
| Linux            | Yes | Full support |
| Windows          | Yes | Full support |
| iOS/tvOS/watchOS | —   | Supported    |
| Swift Embedded   | —   | Pending (nightly-toolchain follow-up) |

---

## Related Packages

- [`swift-memory`](https://github.com/swift/swift-memory) — `Memory.Address` / `Memory.Allocator`, the allocation and layout substrate `Storage.Heap` builds on.
- [`swift-index`](https://github.com/swift/swift-index) — `Index<Element>`, the typed slot positions.
- [`swift-finite`](https://github.com/swift/swift-finite) — `Index.Bounded`, the capacity-bounded index `Storage.Inline` uses.
- [`swift-property`](https://github.com/swift/swift-property) — `Property.Inout`, backing the fluent `initialize` / `move` accessors.
- [`swift-bit-vector`](https://github.com/swift/swift-bit-vector) — bit-vector tracking used by `Storage.Inline`'s initialization map.

---

## Community

<!-- BEGIN: discussion -->
<!-- END: discussion -->

## License

Apache 2.0. See [LICENSE.md](LICENSE.md).
