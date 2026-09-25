#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cat > "$TMP_DIR/main.swift" <<'SWIFT'
import Foundation

func makeDate(
    _ year: Int,
    _ month: Int,
    _ day: Int,
    _ hour: Int,
    _ minute: Int
) -> Date {
    var components = DateComponents()
    components.timeZone = moscowTimeZone
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    components.second = 0

    guard let value = moscowCalendar.date(from: components) else {
        fatalError("Не удалось создать контрольную дату")
    }

    return value
}

func expect(
    _ actual: Int,
    _ expected: Int,
    _ name: String
) {
    guard actual == expected else {
        fputs("FAIL: \(name): expected \(expected), got \(actual)\n", stderr)
        exit(1)
    }

    print("PASS: \(name)")
}

func expect(
    _ condition: Bool,
    _ name: String
) {
    guard condition else {
        fputs("FAIL: \(name)\n", stderr)
        exit(1)
    }

    print("PASS: \(name)")
}

let d1000 = makeDate(2026, 9, 24, 10, 0)
let d1130 = makeDate(2026, 9, 24, 11, 30)
let d0930 = makeDate(2026, 9, 24, 9, 30)

expect(
    minutesBetween(d1000, d1130),
    90,
    "minutesBetween"
)

expect(
    signedMinutesBetween(d1000, d0930),
    -30,
    "signedMinutesBetween negative"
)

expect(
    overlapMinutes(
        start1: makeDate(2026, 9, 24, 10, 0),
        end1: makeDate(2026, 9, 24, 12, 0),
        start2: makeDate(2026, 9, 24, 11, 0),
        end2: makeDate(2026, 9, 24, 13, 0)
    ),
    60,
    "overlapMinutes"
)

let crossMidnightStart = makeDate(2026, 9, 24, 23, 30)
let crossMidnightEnd = makeDate(2026, 9, 25, 0, 30)

expect(
    minutesInDay(
        from: crossMidnightStart,
        to: crossMidnightEnd,
        day: crossMidnightStart
    ),
    30,
    "minutesInDay before midnight"
)

expect(
    minutesInDay(
        from: crossMidnightStart,
        to: crossMidnightEnd,
        day: crossMidnightEnd
    ),
    30,
    "minutesInDay after midnight"
)

expect(
    nightMinutes(
        from: makeDate(2026, 9, 24, 21, 0),
        to: makeDate(2026, 9, 25, 7, 0)
    ),
    480,
    "night 22:00-06:00 across midnight"
)

expect(
    nightMinutes(
        from: makeDate(2026, 9, 24, 5, 30),
        to: makeDate(2026, 9, 24, 6, 30)
    ),
    30,
    "night morning boundary"
)

expect(
    nightMinutes(
        from: makeDate(2026, 9, 24, 21, 30),
        to: makeDate(2026, 9, 24, 22, 30)
    ),
    30,
    "night evening boundary"
)

expect(
    dayKey(makeDate(2026, 9, 24, 12, 0)),
    20260924,
    "dayKey Moscow"
)

let exactMidnightDays = touchedDays(
    from: makeDate(2026, 9, 24, 23, 0),
    to: makeDate(2026, 9, 25, 0, 0)
)

expect(
    exactMidnightDays.count,
    1,
    "touchedDays excludes zero-length next day"
)

let reserveStart = makeDate(2026, 9, 24, 20, 0)
let reserveEnd = makeDate(2026, 9, 25, 8, 0)

let creditedDayOne = creditedMinutesInDay(
    start: reserveStart,
    end: reserveEnd,
    divisor: 4,
    day: reserveStart
)

let creditedDayTwo = creditedMinutesInDay(
    start: reserveStart,
    end: reserveEnd,
    divisor: 4,
    day: reserveEnd
)

expect(
    creditedDayOne + creditedDayTwo,
    180,
    "home reserve credited work across midnight"
)

let creditedNightDayOne = creditedNightMinutesInDay(
    start: reserveStart,
    end: reserveEnd,
    divisor: 4,
    day: reserveStart
)

let creditedNightDayTwo = creditedNightMinutesInDay(
    start: reserveStart,
    end: reserveEnd,
    divisor: 4,
    day: reserveEnd
)

expect(
    creditedNightDayOne + creditedNightDayTwo,
    120,
    "home reserve credited night current rule"
)

expect(
    creditedMinutesInDay(
        start: reserveStart,
        end: reserveEnd,
        divisor: 0,
        day: reserveStart
    ),
    0,
    "invalid divisor is safe"
)

print("All AeroUchet time calculation regression checks passed.")
SWIFT

xcrun swiftc   "$ROOT_DIR/AeroTimeMath.swift"   "$TMP_DIR/main.swift"   -o "$TMP_DIR/aerouchet-core-tests"

"$TMP_DIR/aerouchet-core-tests"
