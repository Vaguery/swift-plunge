//
//  TunerOverlay.swift
//  Plunge
//
//  Tuners as an overlay on a crux: the places a number could be scaled and
//  shifted, and the crux written out with only the chosen tuners in it
//  (2026-11-16).
//

/// **Where a crux could be tuned, and the crux with chosen tuners in place.**
///
/// A tuner scales and shifts one value, `m · x + b`. The overlay lists the
/// places a tuner could go (its ``sites``) without changing the crux; fitting
/// tries settings for some of them and keeps the best, and only the tuners kept
/// are ever written into code, by ``program(_:)``. So a tuner is never applied
/// to a tuner's own arithmetic, and a crux that is tuned again is tuned at the
/// same sites, not wrapped a second time.
///
/// The overlay is built on the distilled crux, rolled with sharing kept
/// (``DistilledCrux/rolledProgram``): constant work is folded (a constant is
/// never a site; it is a parameter already), each loop is written once, and each
/// value is made once however often it is used. A tuner goes on the node that
/// makes a value, so every use of the value sees the same tuning.
///
/// The sites, for now:
/// - **each input**, one site per input slot, the same tuner on every read of it;
/// - **each observed value** (a stack depth, a count of steps or errors), one
///   site per observation.
///
/// Only int and double values are tuned.
///
/// It holds the crux's nodes by identity, so it is used where it is made, not
/// sent between tasks; its sites and settings are plain values that can be.
public nonisolated struct TunerOverlay {
    /// What a site tunes.
    public enum SiteKind: Sendable, Hashable {
        /// Every read of an input slot.
        case input(PushInstruction)
        /// One observed value, made by `source`.
        case observation(source: PushInstruction?)
    }

    /// A place a tuner could go.
    public struct Site: Sendable, Hashable, Identifiable {
        public let id: Int
        public let kind: SiteKind
        /// `.int` or `.double`.
        public let stack: PushStack

        /// A short name: `.input0`, or the observing instruction with the site's
        /// number.
        public var label: String {
            switch kind {
            case .input(let slot): ".\(slot.rawValue)"
            case .observation(let source): ".\(source?.rawValue ?? "observed") #\(id)"
            }
        }
    }

    /// A tuner's setting: the value `m · x + b` for `scale` m and `offset` b. On
    /// an int, both are rounded.
    public struct Setting: Sendable, Hashable {
        public var scale: Double
        public var offset: Double
        public init(scale: Double, offset: Double) {
            self.scale = scale
            self.offset = offset
        }
        /// The setting that changes nothing.
        public static let neutral = Setting(scale: 1, offset: 0)
    }

    /// Tokens one tuner adds where it is written: `m .xMultiply b .xAdd`.
    public static let tokensPerTuner = 4

    public let sites: [Site]
    /// The rolled, shared, distilled history the sites are on.
    let root: any Item
    /// Each observation site's node.
    private let observationSites: [CruxSharing.Key: Int]
    private let inputSites: [PushInstruction: Int]

    init(rolled root: any Item) {
        self.root = root
        var sites: [Site] = []
        var observations: [CruxSharing.Key: Int] = [:]
        var inputs: [PushInstruction: Int] = [:]
        for node in HistoryRewrite.postOrder(root) {
            guard let stack = Self.tunableStack(of: node), let key = CruxSharing.key(node) else { continue }
            if let slot = Self.inputSlot(of: node) {
                guard inputs[slot] == nil else { continue }
                inputs[slot] = sites.count
                sites.append(Site(id: sites.count, kind: .input(slot), stack: stack))
            } else if let source = Self.observationSource(of: node) {
                guard observations[key] == nil else { continue }
                observations[key] = sites.count
                sites.append(Site(id: sites.count, kind: .observation(source: source), stack: stack))
            }
        }
        self.sites = sites
        observationSites = observations
        inputSites = inputs
    }

    /// The crux with no tuners: the rolled, shared, distilled crux.
    public var program: [any Item] { root.crux() }

    /// The crux with a tuner at each site in `settings`, set as given. Sites not
    /// in `settings` get none.
    public func program(_ settings: [Int: Setting]) -> [any Item] {
        guard !settings.isEmpty else { return program }
        return HistoryRewrite.rewrite(root) { node in
            guard let site = site(of: node), let setting = settings[site] else { return nil }
            return Self.tuned(node, setting, on: sites[site].stack)
        }.crux()
    }

    /// The site whose node `node` is, if any.
    private func site(of node: any Item) -> Int? {
        if let slot = Self.inputSlot(of: node) { return inputSites[slot] }
        if Self.observationSource(of: node) != nil, let key = CruxSharing.key(node) { return observationSites[key] }
        return nil
    }

    // MARK: - Nodes

    static func tunableStack(of node: any Item) -> PushStack? {
        if node.exactly(DoubleItem.self) != nil { return .double }
        if node.exactly(IntItem.self) != nil { return .int }
        return nil
    }

    /// The input slot a node reads, if it is an input read.
    static func inputSlot(of node: any Item) -> PushInstruction? {
        let call = node.call
        guard call.count == 1, let token = call[0].exactly(InstructionItem.self)?.value,
              token.isInput else { return nil }
        return token
    }

    /// What observed a node's value, if it is an observed value: its history is
    /// a single observed stand-in.
    static func observationSource(of node: any Item) -> PushInstruction?? {
        let call = node.call
        guard call.count == 1, let standIn = call[0].exactly(StandInItem.self), standIn.reason == .observed
        else { return nil }
        return .some(standIn.source)
    }

    /// `node` followed by its tuner: `node m .xMultiply b .xAdd`.
    static func tuned(_ node: any Item, _ setting: Setting, on stack: PushStack) -> any Item {
        if stack == .int, let value = node.exactly(IntItem.self)?.value {
            let scale = Int(setting.scale.rounded()), offset = Int(setting.offset.rounded())
            let scaled = IntItem(value &* scale, call: [node, IntItem(scale), InstructionItem(.intMultiply)])
            return IntItem(scaled.value &+ offset, call: [scaled, IntItem(offset), InstructionItem(.intAdd)])
        }
        let value = node.exactly(DoubleItem.self)?.value ?? 0
        let scaled = DoubleItem(value * setting.scale,
                                call: [node, DoubleItem(setting.scale), InstructionItem(.doubleMultiply)])
        return DoubleItem(scaled.value + setting.offset,
                          call: [scaled, DoubleItem(setting.offset), InstructionItem(.doubleAdd)])
    }
}

nonisolated extension DistilledCrux {
    /// The places this crux could be tuned, over its rolled, shared form. See
    /// ``TunerOverlay``.
    public var tunerOverlay: TunerOverlay {
        TunerOverlay(rolled: HistoryRewrite.rewrite(item) { HistoryRewrite.foldedPass($0, twoPassBody: 3)?.fold })
    }
}
