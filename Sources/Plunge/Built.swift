//
//  Built.swift
//  Plunge
//
//  A container's value and the origins of its elements, as a typed body returns them.
//

/// **A new container, as an `assembling` or `splitting` body describes it**: its
/// value, and where each element came from. The origins are built only when
/// provenance is being recorded, like every `call`.
///
///     Built(y.value + x.value, members: y.origins(0) + x.origins(1))
nonisolated struct Built<Value> {
    let value: Value
    let members: () -> [Origin]

    init(_ value: Value, members: @autoclosure @escaping () -> [Origin]) {
        self.value = value
        self.members = members
    }
}
