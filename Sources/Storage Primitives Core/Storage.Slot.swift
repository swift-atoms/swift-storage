//// ===----------------------------------------------------------------------===//
////
//// This source file is part of the swift-primitives open source project
////
//// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
//// Licensed under Apache License v2.0
////
//// See LICENSE for license information
////
//// ===----------------------------------------------------------------------===//
//
//public import Affine_Primitives
//public import Index_Primitives
//@_spi(Internal) public import Identity_Primitives
//
//extension Storage {
//    /// A physical slot coordinate in storage [0, capacity).
//    ///
//    /// All storage APIs accept `Index<Storage>`, never `Index<Element>`.
//    /// Buffer disciplines are responsible for mapping logical to physical.
//    ///
//    /// ## Coordinate Spaces
//    ///
//    /// | Type | Space | Domain |
//    /// |------|-------|--------|
//    /// | `Index<Storage>` | Physical | Storage memory [0, capacity) |
//    /// | `Index<Element>` | Logical | ADT positions (user-facing) |
//    public typealias Slot = Index<Storage>
//}
