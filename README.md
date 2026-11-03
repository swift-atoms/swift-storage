# swift-storage

Use this package when you need the raw element column under a container: typed slots over an allocation that you initialize, read and move out of yourself, with no ordering or growth policy of its own. Start from `Storage<Allocation>.Contiguous<Element>` for a dense column over a memory region, whose initialized ranges you describe with a `Store.Initialization` ledger. Start from `Storage<Allocation>.Generational<Element>` for a sparse column over `Memory.Allocator<Memory.Heap>.Pool`, where elements come and go in any order and are reached through `Storage.Generational.Handle` values that detect reuse. When you want a container with a discipline (append order, a ring, growth), use a buffer that composes over these columns, such as `Buffer.Ring`, instead.

## Laws

`Storage.Contiguous`:

- The `initialization` ledger is the only record of which slots hold elements. Teardown deinitializes exactly the ranges it names, and `copy()` copies exactly those ranges and keeps the ledger's shape, including a wrapped one.
- `initialize(at:to:)` and `move(at:)` keep the ledger correct only as a linear prefix `[0, count)`: they set it to one more or one fewer element without checking where the slot is. They are correct for appending at the tail and removing from the tail. Any other pattern, such as removing from the middle or wrapping like `Buffer.Ring`, must set `initialization` itself afterwards.
- The subscript, `initialize(at:to:)` and `move(at:)` do not check the slot against the capacity or the ledger.
- `span`, `mutableSpan`, `outputSpan`, `withOutputSpan(addingCapacity:_:)`, `deinitialize(at:)` and `deinitialize(range:)` require a prefix-shaped ledger, and the two `deinitialize` calls also require the removal to be the ledger's tail. Both are checked only by `assert`, so only in debug builds.
- `outputSpan` and `withOutputSpan(addingCapacity:_:)` write back to the ledger whatever was appended, even when the body throws. The `withOutputSpan` window starts at `count` and must fit within the capacity.
- Capacity is exactly the requested count and never changes. The throwing initializer fails when capacity × stride overflows, and `create(minimumCapacity:)` traps in the same case.

`Storage.Generational`:

- A handle is valid only while its slot is occupied and its generation matches the slot's current generation. A slot's generation starts at 0 and goes up by one on every removal: `remove(_:)`, `move(at:)` and `removeAll()`. Writing through a handle does not change the generation.
- A stale handle is rejected: `contains(_:)` returns false, `remove(_:)` returns nil and `handle(at:)` never rebuilds it, even after the slot is reused. Subscripting with a stale handle traps.
- A fresh pool gives out slots in order 0, 1, 2, …. On the `Store.Protocol` surface, `initialize(at:to:)` is allowed only at the slot the pool would give out next, and the positional subscript and `move(at:)` trap on an empty slot.
- Slot capacity is fixed and must be positive. `insert(_:)` traps when every slot is full. `grow(to:)` never shrinks; it moves elements into a new pool without destroying or copying them, and keeps every slot's index, occupancy and generation, so live handles still work and stale handles stay stale.
- `clone()` keeps every slot's index, occupancy and generation, and returns an independent copy whose free slots really are free.
- `remove(_:)` and `move(at:)` hand the element out without destroying it. Teardown and `removeAll()` destroy each element still stored exactly once. `forEach(_:)` visits occupied slots in ascending index order.
