public import Index

extension __StoreProtocol where Self: ~Copyable {

    @inlinable
    public mutating func move(from source: Index<Element>, to destination: Index<Element>) {
        guard source != destination else { return }
        initialize(at: destination, to: move(at: source))
    }

    @inlinable
    public mutating func moveInitialize(
        from source: Index<Element>,
        to destination: Index<Element>,
        count: Index<Element>.Count
    ) {
        guard count > .zero, source != destination else { return }
        if destination > source {

            var remaining: Index<Element>.Count = count
            while remaining > .zero {
                let step: Index<Element>.Count = remaining.subtracting(saturating: .one)

                let sourceSlot = source.advanced(by: step)

                let destinationSlot = destination.advanced(by: step)
                move(from: sourceSlot, to: destinationSlot)
                remaining = step
            }
        } else {

            var sourceSlot = source
            var destinationSlot = destination
            var step: Index<Element>.Count = .zero
            while step < count {
                move(from: sourceSlot, to: destinationSlot)
                sourceSlot += .one
                destinationSlot += .one
                step = step.adding(saturating: .one)
            }
        }
    }
}
