// MARK: - @_rawLayout Wrapper Validation
// Purpose: Validate that the wrapper approach works for Storage.Inline:
//   1. @_rawLayout internal type for automatic layout
//   2. Wrapper struct with initialization tracking
//   3. Pointer access to raw storage
//   4. Sendable conformance handling
//
// Hypothesis: Wrapper approach achieves optimal layout while preserving
//   initialization tracking.
//
// Toolchain: Swift 6.2 (Xcode 26)
// Platform: macOS 26 (arm64)
//
// Result: CONFIRMED - all approaches work, wrapper adds 17-byte init overhead
// Date: 2026-02-05

// ============================================================================
// MARK: - Approach A: Basic Wrapper Structure
// Hypothesis: Wrapper can contain @_rawLayout storage + other fields
// Result: CONFIRMED - InlineStorage<Double, 4> = 49 bytes (32 raw + 17 init)
// ============================================================================

/// Internal raw storage with automatic layout (no stored properties)
/// Note: @_rawLayout types are ALWAYS ~Copyable, must use @unchecked Sendable
@_rawLayout(likeArrayOf: Element, count: capacity)
struct _RawStorage<Element: ~Copyable, let capacity: Int>: ~Copyable, @unchecked Sendable {}

/// Simulated initialization tracking (simplified from real Storage.Initialization)
enum Initialization: Sendable {
    case empty
    case range(start: Int, end: Int)
}

/// Public wrapper combining raw storage + initialization
/// Note: Cannot have conditional Copyable because _RawStorage is always ~Copyable
struct InlineStorage<Element: ~Copyable, let capacity: Int>: ~Copyable {
    var _storage: _RawStorage<Element, capacity>
    var _initialization: Initialization

    init() {
        _storage = _RawStorage()  // @_rawLayout synthesizes init()
        _initialization = .empty
    }
}

// Sendable conformance on wrapper (requires @unchecked because _RawStorage is @unchecked)
extension InlineStorage: @unchecked Sendable where Element: Sendable {}

func testApproachA() {
    print("=== Approach A: Basic Wrapper Structure ===")
    print()

    // Check raw storage sizes
    print("_RawStorage sizes (should be optimal):")
    print("  _RawStorage<Double, 4>: \(MemoryLayout<_RawStorage<Double, 4>>.size) bytes (ideal: 32)")
    print("  _RawStorage<UInt8, 16>: \(MemoryLayout<_RawStorage<UInt8, 16>>.size) bytes (ideal: 16)")
    print("  _RawStorage<Int32, 8>:  \(MemoryLayout<_RawStorage<Int32, 8>>.size) bytes (ideal: 32)")
    print()

    // Check wrapper sizes (raw + initialization)
    let initSize = MemoryLayout<Initialization>.size
    print("Initialization size: \(initSize) bytes")
    print()

    print("InlineStorage sizes (raw + init overhead):")
    print("  InlineStorage<Double, 4>: \(MemoryLayout<InlineStorage<Double, 4>>.size) bytes (raw: 32 + init: \(initSize))")
    print("  InlineStorage<UInt8, 16>: \(MemoryLayout<InlineStorage<UInt8, 16>>.size) bytes (raw: 16 + init: \(initSize))")
    print("  InlineStorage<Int32, 8>:  \(MemoryLayout<InlineStorage<Int32, 8>>.size) bytes (raw: 32 + init: \(initSize))")
    print()
}

// ============================================================================
// MARK: - Approach B: Pointer Access
// Hypothesis: Can get pointer to elements via withUnsafePointer to _storage
// Result: CONFIRMED - [0]=1.0, [1]=2.0, [2]=3.0, [3]=4.0
// ============================================================================

extension InlineStorage where Element: ~Copyable {
    func pointer(at index: Int) -> UnsafePointer<Element> {
        unsafe withUnsafePointer(to: _storage) { base in
            let raw = UnsafeRawPointer(base)
            return unsafe raw.advanced(by: index * MemoryLayout<Element>.stride)
                .assumingMemoryBound(to: Element.self)
        }
    }

    mutating func mutablePointer(at index: Int) -> UnsafeMutablePointer<Element> {
        unsafe withUnsafeMutablePointer(to: &_storage) { base in
            let raw = UnsafeMutableRawPointer(base)
            return unsafe raw.advanced(by: index * MemoryLayout<Element>.stride)
                .assumingMemoryBound(to: Element.self)
        }
    }

    mutating func initialize(to element: consuming Element, at index: Int) {
        unsafe mutablePointer(at: index).initialize(to: element)
    }

    mutating func move(at index: Int) -> Element {
        unsafe mutablePointer(at: index).move()
    }
}

func testApproachB() {
    print("=== Approach B: Pointer Access ===")
    print()

    // Test with Copyable element
    print("InlineStorage<Double, 4> functional test:")
    var storage = InlineStorage<Double, 4>()
    storage.initialize(to: 1.0, at: 0)
    storage.initialize(to: 2.0, at: 1)
    storage.initialize(to: 3.0, at: 2)
    storage.initialize(to: 4.0, at: 3)
    print("  [0]=\(storage.move(at: 0)), [1]=\(storage.move(at: 1)), [2]=\(storage.move(at: 2)), [3]=\(storage.move(at: 3))")
    print()

    // Test with different element type
    print("InlineStorage<Int32, 8> functional test:")
    var intStorage = InlineStorage<Int32, 8>()
    for i: Int32 in 0..<8 {
        intStorage.initialize(to: i * 10, at: Int(i))
    }
    print("  [0]=\(intStorage.move(at: 0)), [4]=\(intStorage.move(at: 4)), [7]=\(intStorage.move(at: 7))")
    for i in 1..<4 { _ = intStorage.move(at: i) }
    for i in 5..<7 { _ = intStorage.move(at: i) }
    print()
}

// ============================================================================
// MARK: - Approach C: ~Copyable Elements
// Hypothesis: Works with move-only types
// Result: CONFIRMED - Resource(a:10, b:20) stored and moved correctly
// ============================================================================

struct Resource: ~Copyable, @unchecked Sendable {
    var a: Int
    var b: Int
}

func testApproachC() {
    print("=== Approach C: ~Copyable Elements ===")
    print()

    print("Resource (16-byte ~Copyable):")
    print("  size=\(MemoryLayout<Resource>.size), stride=\(MemoryLayout<Resource>.stride)")
    print()

    print("_RawStorage<Resource, 4>:")
    print("  size=\(MemoryLayout<_RawStorage<Resource, 4>>.size) bytes (ideal: 64)")
    print()

    print("InlineStorage<Resource, 4>:")
    let initSize = MemoryLayout<Initialization>.size
    print("  size=\(MemoryLayout<InlineStorage<Resource, 4>>.size) bytes (raw: 64 + init: \(initSize))")
    print()

    // Functional test
    print("InlineStorage<Resource, 4> functional test:")
    var storage = InlineStorage<Resource, 4>()
    storage.initialize(to: Resource(a: 10, b: 20), at: 0)
    storage.initialize(to: Resource(a: 30, b: 40), at: 1)
    let r0 = storage.move(at: 0)
    let r1 = storage.move(at: 1)
    print("  [0].a=\(r0.a), [0].b=\(r0.b)")
    print("  [1].a=\(r1.a), [1].b=\(r1.b)")
    print()
}

// ============================================================================
// MARK: - Approach D: Alignment Verification
// Hypothesis: Alignment is preserved correctly through wrapper
// Result: CONFIRMED - _RawStorage<Double, 4> alignment = 8
// ============================================================================

struct Aligned16: ~Copyable {
    var x: Int
    var y: Int
}

func testApproachD() {
    print("=== Approach D: Alignment Verification ===")
    print()

    print("Alignment check:")
    print("  _RawStorage<Double, 4> alignment: \(MemoryLayout<_RawStorage<Double, 4>>.alignment) (should be 8)")
    print("  _RawStorage<UInt8, 16> alignment: \(MemoryLayout<_RawStorage<UInt8, 16>>.alignment) (should be 1)")
    print("  _RawStorage<Aligned16, 4> alignment: \(MemoryLayout<_RawStorage<Aligned16, 4>>.alignment) (should be 8)")
    print()

    print("Wrapper alignment (may be affected by Initialization):")
    print("  InlineStorage<Double, 4> alignment: \(MemoryLayout<InlineStorage<Double, 4>>.alignment)")
    print("  InlineStorage<UInt8, 16> alignment: \(MemoryLayout<InlineStorage<UInt8, 16>>.alignment)")
    print()
}

// ============================================================================
// MARK: - Approach E: Comparison with Current Implementation
// Hypothesis: Wrapper is significantly smaller than 64-byte slots
// Result: CONFIRMED - 70-96% savings vs 64-byte slots
// ============================================================================

func testApproachE() {
    print("=== Approach E: Comparison with 64-byte Slots ===")
    print()

    let initSize = MemoryLayout<Initialization>.size

    print("Element      | Count | @_rawLayout | Wrapper    | 64B Slots | Savings")
    print("-------------|-------|-------------|------------|-----------|--------")

    func row(_ name: String, _ count: Int, _ raw: Int, _ wrapper: Int, _ fixed: Int) {
        let savings = Int((1.0 - Double(wrapper)/Double(fixed)) * 100)
        print("\(name)  \(count)      \(raw) B         \(wrapper) B        \(fixed) B      \(savings)%")
    }

    row("Double      ", 4,
        MemoryLayout<_RawStorage<Double, 4>>.size,
        MemoryLayout<InlineStorage<Double, 4>>.size,
        4 * 64 + initSize)

    row("UInt8       ", 16,
        MemoryLayout<_RawStorage<UInt8, 16>>.size,
        MemoryLayout<InlineStorage<UInt8, 16>>.size,
        16 * 64 + initSize)

    row("Int32       ", 8,
        MemoryLayout<_RawStorage<Int32, 8>>.size,
        MemoryLayout<InlineStorage<Int32, 8>>.size,
        8 * 64 + initSize)

    row("Resource    ", 4,
        MemoryLayout<_RawStorage<Resource, 4>>.size,
        MemoryLayout<InlineStorage<Resource, 4>>.size,
        4 * 64 + initSize)

    print()
}

// ============================================================================
// MARK: - Approach F: Copyable Constraint Analysis
// Hypothesis: Conditional Copyable on wrapper is NOT possible
// Result: CONFIRMED - wrapper must be ~Copyable (acceptable)
// ============================================================================

func testApproachF() {
    print("=== Approach F: Copyable Constraint Analysis ===")
    print()

    print("Key findings:")
    print("  - @_rawLayout types are ALWAYS ~Copyable (cannot be Copyable)")
    print("  - Wrapper containing @_rawLayout type cannot have conditional Copyable")
    print("  - This matches existing Storage.Inline which is ~Copyable by design")
    print()

    print("Conformance summary:")
    print("  _RawStorage: ~Copyable (required), @unchecked Sendable")
    print("  InlineStorage: ~Copyable, @unchecked Sendable where Element: Sendable")
    print()

    print("This is acceptable because:")
    print("  - Storage.Inline is already ~Copyable in the current implementation")
    print("  - The conditional Copyable conformance was only for convenience")
    print("  - ~Copyable is the correct semantic for storage that tracks initialization")
    print()
}

// ============================================================================
// MARK: - Summary
// ============================================================================

func printSummary() {
    print("=== SUMMARY ===")
    print()
    print("Wrapper approach validation:")
    print("  1. @_rawLayout internal type: WORKS (optimal sizes)")
    print("  2. Wrapper with _initialization: WORKS (additional overhead only)")
    print("  3. Pointer access to _storage: WORKS (correct element access)")
    print("  4. ~Copyable elements: WORKS (move semantics preserved)")
    print("  5. Sendable conformance: WORKS (@unchecked Sendable required)")
    print("  6. Copyable conformance: NOT POSSIBLE (@_rawLayout always ~Copyable)")
    print()
    print("Impact on Storage.Inline:")
    print("  - Remove conditional Copyable conformance")
    print("  - Keep ~Copyable (matches current design intent)")
    print("  - Use @unchecked Sendable for _RawStorage")
    print()
    print("Recommended implementation:")
    print("  @_rawLayout(likeArrayOf: Element, count: capacity)")
    print("  struct _RawInlineStorage<...>: ~Copyable, @unchecked Sendable {}")
    print()
    print("  struct Inline<...>: ~Copyable {")
    print("      var _storage: _RawInlineStorage<Element, capacity>")
    print("      var _initialization: Initialization")
    print("  }")
    print("  extension Inline: @unchecked Sendable where Element: Sendable {}")
}

// ============================================================================
// MARK: - Execution
// ============================================================================

testApproachA()
testApproachB()
testApproachC()
testApproachD()
testApproachE()
testApproachF()
printSummary()
