import Foundation

/// The one budget rule shared by the Payday tab, the Payday review and "Still want it?".
///
/// - Quick thaws (price under the timer threshold) never count against fun money (D2, D4).
/// - Payday wants are walked in `thawsAt` order; each want that still fits the money left is kept,
///   even after an earlier one overflowed (D5, best fit in thaw order).
nonisolated struct FunMoneyPlan: Equatable, Sendable {
    struct Entry: Equatable, Sendable {
        let want: Want
        let fits: Bool
    }

    /// Payday wants in thaw order, each marked as fitting or over budget.
    let payday: [Entry]
    /// Quick thaws in thaw order. They don't count against fun money.
    let quickThaws: [Want]
    let funMoney: Decimal

    var fits: [Want] { payday.filter(\.fits).map(\.want) }
    var over: [Want] { payday.filter { !$0.fits }.map(\.want) }
    /// Every want in the plan: payday wants first, then quick thaws.
    var ordered: [Want] { payday.map(\.want) + quickThaws }

    /// Every payday want, kept or not: what the Payday tab sets against fun money.
    var paydayTotal: Decimal { Self.total(payday.map(\.want)) }
    /// Payday wants that fit: what the review keeps by default.
    var fitsTotal: Decimal { Self.total(fits) }
    var quickTotal: Decimal { Self.total(quickThaws) }

    /// Spoken-for when every payday want is kept. Exactly on budget is not over.
    var isOver: Bool { paydayTotal > funMoney }
    var left: Decimal { max(0, funMoney - paydayTotal) }
    var overBy: Decimal { max(0, paydayTotal - funMoney) }

    static func isQuickThaw(_ want: Want, timerThreshold: Decimal) -> Bool {
        want.price < timerThreshold
    }

    static func make(wants: [Want], funMoney: Decimal, timerThreshold: Decimal) -> FunMoneyPlan {
        let sorted = wants.enumerated()
            .sorted { ($0.element.thawsAt, $0.offset) < ($1.element.thawsAt, $1.offset) }
            .map(\.element)
        var remaining = funMoney
        var payday: [Entry] = []
        var quick: [Want] = []
        for want in sorted {
            if isQuickThaw(want, timerThreshold: timerThreshold) {
                quick.append(want)
            } else if want.price <= remaining {
                remaining -= want.price
                payday.append(Entry(want: want, fits: true))
            } else {
                payday.append(Entry(want: want, fits: false))
            }
        }
        return FunMoneyPlan(payday: payday, quickThaws: quick, funMoney: funMoney)
    }

    /// The meter for a set of kept wants: only payday wants in this plan count.
    func summary(keeping ids: Set<UUID>) -> FunMoneySummary {
        FunMoneySummary.make(keptPrices: payday.map(\.want).filter { ids.contains($0.id) }.map(\.price),
                             budget: funMoney)
    }

    private static func total(_ wants: [Want]) -> Decimal {
        wants.reduce(Decimal(0)) { $0 + $1.price }
    }
}
