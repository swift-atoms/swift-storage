# Data Structures

Complete reference of data structure primitives available in swift-primitives.

## Overview

Data structures follow a consistent variant pattern based on storage strategy:

| Variant | Storage | Capacity | Use Case |
|---------|---------|----------|----------|
| Base / Unbounded | Heap (ManagedBuffer) | Dynamic | General purpose |
| Bounded | Heap (fixed allocation) | Fixed, throws on overflow | Known maximum size |
| Inline | Inline (InlineArray) | Compile-time fixed | Zero allocation, stack-only |
| Small | Inline → Heap spill | Hybrid | Optimized for small N |

## swift-array-primitives

Contiguous element storage with O(1) random access.

| Type | Storage | Capacity |
|------|---------|----------|
| `Array.Unbounded` | Heap (ManagedBuffer) | Dynamic |
| `Array.Bounded` | Heap (fixed allocation) | Fixed, throws on overflow |
| `Array.Inline<let capacity: Int>` | Inline (InlineArray) | Compile-time fixed |
| `Array.Small<let inlineCapacity: Int>` | Inline → Heap spill | Hybrid |

## swift-set-primitives

Unique element collections with O(1) membership testing.

| Type | Storage | Capacity |
|------|---------|----------|
| `Set.Ordered` | Heap (ManagedBuffer + Dictionary) | Dynamic |
| `Set.Ordered.Bounded` | Heap (fixed allocation) | Fixed, throws on overflow |
| `Set.Ordered.Inline<let capacity: Int>` | Inline | Compile-time fixed |
| `Set.Ordered.Small<let inlineCapacity: Int>` | Inline → Heap spill | Hybrid |

## swift-dictionary-primitives

Key-value mapping with preserved insertion order.

| Type | Storage | Capacity |
|------|---------|----------|
| `Dictionary.Ordered` | Heap | Dynamic |

## swift-bit-primitives

Bit-packed collections for space-efficient boolean and index storage.

### Bit Array

Packed boolean array using word-sized storage. 8x space efficiency over `[Bool]`.

| Type | Storage | Capacity |
|------|---------|----------|
| `Array<Bit>.Packed` | Heap (ContiguousArray&lt;UInt&gt;) | Dynamic |
| `Array<Bit>.Packed.Bounded` | Heap | Fixed |
| `Array<Bit>.Packed.Inline<let wordCount: Int>` | Inline (InlineArray&lt;UInt&gt;) | Compile-time fixed |

### Bit Set

Packed set of bit indices with O(1) insert/remove/contains and full set algebra.

| Type | Storage | Capacity |
|------|---------|----------|
| `Set<Bit.Index>.Packed` | Heap (ContiguousArray&lt;UInt&gt;) | Dynamic |
| `Set<Bit.Index>.Packed.Bounded` | Heap | Fixed |
| `Set<Bit.Index>.Packed.Inline<let wordCount: Int>` | Inline (InlineArray&lt;UInt&gt;) | Compile-time fixed |

## swift-buffer-primitives

Raw memory and specialized buffer types.

| Type | Storage | Capacity |
|------|---------|----------|
| `Buffer.Unbounded` | Heap | Dynamic |
| `Buffer.Bounded` | Heap | Fixed |
| `Buffer.Aligned` | Heap (aligned) | Fixed |
| `Buffer.Ring.Unbounded` | Heap (circular) | Dynamic |
| `Buffer.Ring.Bounded` | Heap (circular) | Fixed |
| `Buffer.Slots.Bounded` | Heap (slot-based) | Fixed |

## swift-deque-primitives

Double-ended queue with O(1) push/pop at both ends.

| Type | Storage | Capacity |
|------|---------|----------|
| `Deque` | Heap (ring buffer) | Dynamic |
| `Deque.Inline<let capacity: Int>` | Inline | Compile-time fixed |
| `Deque.Small<let inlineCapacity: Int>` | Inline → Heap spill | Hybrid |

## swift-stack-primitives

LIFO (last-in, first-out) collection.

| Type | Storage | Capacity |
|------|---------|----------|
| `Stack` | Heap | Dynamic |
| `Stack.Bounded` | Heap | Fixed |
| `Stack.Inline<let capacity: Int>` | Inline | Compile-time fixed |
| `Stack.Small<let inlineCapacity: Int>` | Inline → Heap spill | Hybrid |

## swift-queue-primitives

FIFO (first-in, first-out) collection.

| Type | Storage | Capacity |
|------|---------|----------|
| `Queue` | Heap | Dynamic |
| `Queue.Bounded` | Heap | Fixed |
| `Queue.Inline<let capacity: Int>` | Inline | Compile-time fixed |
| `Queue.Small<let inlineCapacity: Int>` | Inline → Heap spill | Hybrid |

## swift-heap-primitives

Priority queue with O(log n) push/pop.

| Type | Storage | Capacity |
|------|---------|----------|
| `Heap` | Heap | Dynamic |

## swift-list-primitives

Linked list with O(1) insertion/removal at known positions.

| Type | Storage | Capacity |
|------|---------|----------|
| `List.Linked` | Heap (nodes) | Dynamic |
| `List.Linked.Bounded` | Heap | Fixed |
| `List.Linked.Inline<let capacity: Int>` | Inline | Compile-time fixed |
| `List.Linked.Small<let inlineCapacity: Int>` | Inline → Heap spill | Hybrid |

## swift-tree-primitives

Hierarchical data structures.

| Type | Storage | Capacity |
|------|---------|----------|
| `Tree.Binary` | Heap | Dynamic |
| `Tree.Binary.Bounded` | Heap | Fixed |
| `Tree.Binary.Inline<let capacity: Int>` | Inline | Compile-time fixed |
| `Tree.Binary.Small<let inlineCapacity: Int>` | Inline → Heap spill | Hybrid |

## swift-graph-primitives

Node and edge collections with traversal algorithms.

| Type | Storage | Capacity |
|------|---------|----------|
| `Graph.Sequential` | Heap (adjacency) | Dynamic |

## swift-slab-primitives

Arena-style allocation for bulk object management.

| Type | Storage | Capacity |
|------|---------|----------|
| `Slab` | Heap (arena) | Dynamic |

## Variant Selection Guide

Choose the appropriate variant based on your requirements:

| Requirement | Recommended Variant |
|-------------|---------------------|
| Unknown or large N | Base / Unbounded |
| Known maximum, want overflow detection | Bounded |
| Small fixed N, zero allocation critical | Inline |
| Usually small, occasionally large | Small |

## See Also

- ``API Requirements``
- ``Memory Ownership``
- ``Memory Copyable``
