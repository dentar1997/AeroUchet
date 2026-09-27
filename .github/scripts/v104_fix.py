from pathlib import Path

path = Path("FullEditorTest3View.swift")
text = path.read_text()

old = """        let minimum = previousEventDate(id) ?? workStart
        let maximum = maximumAllowedEventDate
        let clamped = min(max(candidate, minimum), maximum)
        setEventDate(id, clamped)
"""
new = """        let minimum = minimumAllowedEventDate(id)
        let maximum = maximumAllowedEventDate
        let clamped = min(max(candidate, minimum), maximum)
        setEventDate(id, clamped)
"""
if old not in text:
    raise SystemExit("applyEventCandidate block not found")
text = text.replace(old, new, 1)

old = """    private func normalizeFollowingEvents(after id: FullTest3EventID) {
        var previous = eventDate(id)

        for next in id.following {
            var candidate = eventDate(next)
            candidate = min(candidate, maximumAllowedEventDate)
            if candidate < previous {
                candidate = previous
            }
            setEventDate(next, candidate)
            previous = candidate
        }
    }

    private var maximumAllowedEventDate: Date {
        let startOfDay = fullTest3Calendar.startOfDay(for: workStart)
        let dayAfterNext = fullTest3Calendar.date(byAdding: .day, value: 2, to: startOfDay) ?? workStart
        return dayAfterNext.addingTimeInterval(-60)
    }
"""
new = """    private func normalizeFollowingEvents(after id: FullTest3EventID) {
        for next in id.following {
            var candidate = eventDate(next)
            candidate = min(candidate, maximumAllowedEventDate)
            let minimum = minimumAllowedEventDate(next)
            if candidate < minimum {
                candidate = minimum
            }
            setEventDate(next, candidate)
        }
    }

    private func minimumAllowedEventDate(_ id: FullTest3EventID) -> Date {
        switch id {
        case .workStart:
            return workStart
        case .engineStart:
            return workStart
        case .takeoff:
            return engineStart
        case .landing:
            return takeoff
        case .engineStop:
            return landing
        case .workEnd:
            let offset = isLastLeg ? 30 : 0
            return fullTest3Calendar.date(byAdding: .minute, value: offset, to: engineStop) ?? engineStop
        }
    }

    private var maximumAllowedEventDate: Date {
        fullTest3Calendar.date(byAdding: .minute, value: 15 * 60, to: workStart) ?? workStart
    }
"""
if old not in text:
    raise SystemExit("normalize/max block not found")
text = text.replace(old, new, 1)

old = """        if let previous = previousEventDate(id), candidate < previous {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }

        setEventDate(id, min(candidate, maximumAllowedEventDate))
"""
new = """        if candidate < minimumAllowedEventDate(id) || candidate > maximumAllowedEventDate {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }

        setEventDate(id, candidate)
"""
if old not in text:
    raise SystemExit("toggle validation block not found")
text = text.replace(old, new, 1)

old = """            var candidate = fullTest3Calendar.date(from: components) ?? previous
            candidate = min(candidate, maximumAllowedEventDate)
            if candidate < previous {
                candidate = previous
            }
            setEventDate(next, candidate)
            previous = candidate
"""
new = """            var candidate = fullTest3Calendar.date(from: components) ?? previous
            candidate = min(candidate, maximumAllowedEventDate)
            let minimum = minimumAllowedEventDate(next)
            if candidate < minimum {
                candidate = minimum
            }
            setEventDate(next, candidate)
            previous = candidate
"""
if old not in text:
    raise SystemExit("force following block not found")
text = text.replace(old, new, 1)

path.write_text(text)
