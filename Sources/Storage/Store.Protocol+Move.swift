import Affine_Standard_Library_Integration
public import Index
import Ordinal_Standard_Library_Integration

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
                let step: Index<Element>.Count = remaining.subtract.saturating(.one)
                let offset = Index<Element>.Offset(fromZero: step.map(Ordinal.init))

                let sourceSlot = try! source + offset

                let destinationSlot = try! destination + offset
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
                step = step.add.saturating(.one)
            }
        }
    }
}
