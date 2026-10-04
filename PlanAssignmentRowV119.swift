import Foundation
import SwiftUI


struct PlanAssignmentRowV119: View {
    let item: AssignmentPlanItem
    var status: String?
    var statusColor: Color = .secondary
    var conflictText: String?
    var perspectiveStyle = false

    private var effectiveConflictText: String? {
        if let conflictText { return conflictText }
        guard perspectiveStyle, item.kind == .flight else { return nil }
        return PerspectiveDutyBuilderV129.routeConflict(item: item)
    }

    @ObservedObject private var appearanceStore = AssignmentAppearanceStore.shared
    @ObservedObject private var scheduleStore = FlightScheduleStoreV129.shared

    private var metadata: AssignmentV119Metadata? {
        AssignmentV119MetadataCodec.metadata(from: item.detail)
    }

    private var eventType: AssignmentEventType {
        if perspectiveStyle,
           item.title.trimmingCharacters(in: .whitespacesAndNewlines)
               .lowercased().hasPrefix("явка") {
            return .appearance
        }
        return AssignmentEventType.resolve(item)
    }

    private var iconStyle: AssignmentIconStyle {
        appearanceStore.style(for: eventType)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 4) {
                AssignmentEventIconView(
                    eventType: eventType,
                    style: iconStyle,
                    size: 23
                )
                .frame(width: 26, height: 26)

                if metadata?.linkedGroupID != nil, !perspectiveStyle {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(iconStyle.color.color.opacity(0.30))
                        .frame(width: 2, height: 22)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                if item.kind == .flight {
                    workingFlightContent
                } else if item.kind == .passenger {
                    passengerContent
                } else {
                    groundContent
                }

                if let status {
                    Label(status, systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption2)
                        .foregroundStyle(statusColor)
                }

                if metadata?.linkedGroupID != nil, !perspectiveStyle {
                    Label("Связанное событие", systemImage: "link")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let conflictText = effectiveConflictText {
                    Label(conflictText, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(dateLabel)
                    .font(.caption)
                    .foregroundStyle(
                        effectiveConflictText == nil
                            ? Color.secondary
                            : Color.red
                    )
                    .multilineTextAlignment(.trailing)

                if let timeRange {
                    Text(timeRange)
                        .font(.caption.monospacedDigit())
                        .multilineTextAlignment(.trailing)
                }

                if let secondaryTimeRange {
                    Text(secondaryTimeRange)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.trailing)
                }

                if shouldShowGroundDuration {
                    Text(timeText(item.durationMinutes))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, effectiveConflictText == nil ? 0 : 8)
        .background {
            if effectiveConflictText != nil {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.red.opacity(0.10))
            }
        }
    }

    private var workingFlightContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(displayLegs, id: \.id) { leg in
                Text(legText(leg))
                    .font(.subheadline.weight(.semibold))
            }

            if displayLegs.isEmpty {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
            }

            HStack(spacing: 6) {
                Text("Полётная смена: \(timeText(item.durationMinutes))")
                if let flightMinutes = displayedFlightMinutes {
                    Text("·")
                    Text("Полётное время: \(timeText(flightMinutes))")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let reduction = metadata?.subsequentDutyReductionMinutes,
               reduction > 0 {
                Text("Макс. продолж. полётной смены уменьшена на \(timeText(reduction))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if perspectiveStyle,
               let total = metadata?.linkedSequenceMinutes,
               total > 0 {
                Text(
                    "Полётная смена + Перемещ. в кач. пассаж. = \(timeText(total)) ≤ Макс. продолж. полётной смены + 02:00"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var passengerContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(displayLegs, id: \.id) { leg in
                Text(legText(leg))
                    .font(.subheadline.weight(.semibold))
            }

            if displayLegs.isEmpty {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
            }

            Text(passengerCaption)
                .font(perspectiveStyle ? .caption : .caption2.weight(.bold))
                .foregroundStyle(perspectiveStyle ? Color.secondary : iconStyle.color.color)

            if !perspectiveStyle,
               let sourceStart = metadata?.sourceStart,
               let sourceEnd = metadata?.sourceEnd {
                Text("\(clock(sourceStart)) — \(clock(sourceEnd))")
                    .font(.caption.monospacedDigit())
            }

            if !perspectiveStyle,
               let sourceMinutes = sourcePassengerMinutes,
               let movement = metadata?.passengerMovementMinutes {
                Text(
                    "Перемещение в качестве пассажира: \(timeText(sourceMinutes)) + 0:40 = \(timeText(movement))"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            } else if !perspectiveStyle,
                      let movement = metadata?.passengerMovementMinutes {
                Text("Перемещение в качестве пассажира: \(timeText(movement))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !perspectiveStyle,
               let waiting = metadata?.waitingMinutes,
               waiting > 0 {
                Text("Время ожидания: \(timeText(waiting))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !perspectiveStyle,
               let total = metadata?.linkedSequenceMinutes,
               total > 0 {
                Text(
                    "Смена + перемещение: \(timeText(total)) / лимит: норма смены + 2:00"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
            }
        }
    }

    private var groundContent: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(groundTitle)
                .font(.subheadline.weight(.semibold))

            if let detail = groundDetail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var groundTitle: String {
        guard eventType == .simulatorCTS,
              let aircraft = displayGroundAircraft,
              !aircraft.isEmpty else {
            return item.title
        }
        return "\(item.title) · \(aircraft)"
    }

    private var displayGroundAircraft: String? {
        if let aircraft = normalizeAircraft(item.aircraft), !aircraft.isEmpty {
            return aircraft
        }
        guard let raw = AssignmentV119MetadataCodec.humanDetail(item.detail),
              let regex = try? NSRegularExpression(
                pattern: #"\b(?:A|B)-?\d{3,4}[A-Z]?\b"#,
                options: [.caseInsensitive]
              ) else {
            return nil
        }
        let ns = raw as NSString
        guard let match = regex.firstMatch(
            in: raw,
            range: NSRange(location: 0, length: ns.length)
        ) else {
            return nil
        }
        return normalizeAircraft(ns.substring(with: match.range))
    }

    private struct DisplayLeg: Identifiable {
        var id: String
        var flightNumber: String
        var departure: String?
        var arrival: String?
        var aircraft: String?
    }

    private var displayLegs: [DisplayLeg] {
        if let metadata, !metadata.legs.isEmpty {
            return metadata.legs.enumerated().map { index, leg in
                DisplayLeg(
                    id: "meta|\(item.id)|\(index)",
                    flightNumber: displayFlightNumber(leg.flightNumber),
                    departure: leg.departure.map(expandAirport),
                    arrival: leg.arrival.map(expandAirport),
                    aircraft: normalizeAircraft(leg.aircraft)
                )
            }
        }

        if let legs = item.flightLegs, !legs.isEmpty {
            return legs.enumerated().map { index, leg in
                DisplayLeg(
                    id: "leg|\(item.id)|\(index)",
                    flightNumber: displayFlightNumber(leg.flightNumber),
                    departure: leg.departure.map(expandAirport),
                    arrival: leg.arrival.map(expandAirport),
                    aircraft: normalizeAircraft(item.aircraft)
                )
            }
        }

        if let number = item.flightNumber {
            return [
                DisplayLeg(
                    id: "single|\(item.id)",
                    flightNumber: displayFlightNumber(number),
                    departure: item.departure.map(expandAirport),
                    arrival: item.arrival.map(expandAirport),
                    aircraft: normalizeAircraft(item.aircraft)
                )
            ]
        }
        return []
    }

    private func legText(_ leg: DisplayLeg) -> String {
        var parts = [leg.flightNumber]
        if perspectiveStyle,
           !scheduleStore.entries.isEmpty,
           let match = PerspectiveDutyBuilderV129.scheduleDisplay(
                flightNumber: leg.flightNumber,
                date: metadata?.sourceStart ?? item.start,
                departureHint: leg.departure,
                arrivalHint: leg.arrival
           ) {
            let departure = DutyAutofillV129.displayAirport(
                code: match.entry.departure,
                terminal: match.entry.departureTerminal
            )
            let arrival = DutyAutofillV129.displayAirport(
                code: match.entry.arrival,
                terminal: match.entry.arrivalTerminal
            )
            parts.append("\(departure) → \(arrival)")
        } else if let departure = leg.departure,
                  let arrival = leg.arrival {
            parts.append("\(departure) → \(arrival)")
        }
        if let aircraft = leg.aircraft, !aircraft.isEmpty {
            parts.append(AircraftFamilyV129.display(aircraft))
        }
        return parts.joined(separator: " · ")
    }

    private var displayedFlightMinutes: Int? {
        if let value = item.plannedFlightMinutes {
            return value
        }
        return plannedMinutesMarker(in: item.detail)
    }

    private var passengerCaption: String {
        guard perspectiveStyle else {
            let basis = metadata?.passengerBasis?.uppercased() ?? "ПО ЗАДАНИЮ"
            return "ПЕРЕЛЁТ ПАССАЖИРОМ \(basis)"
        }

        let movementText: String
        if let movement = metadata?.passengerMovementMinutes, movement > 0 {
            movementText = "Перемещение в качестве пассажира: \(timeText(movement))"
        } else {
            movementText = "Перемещение в качестве пассажира"
        }

        guard metadata?.linkedGroupID != nil,
              let waiting = metadata?.waitingMinutes,
              waiting > 0 else {
            return movementText
        }

        let waitingText = "Время ожидания: \(timeText(waiting))"
        if metadata?.linkedSequenceMinutes != nil {
            return "\(waitingText) · \(movementText)"
        }
        return "\(movementText) · \(waitingText)"
    }

    private var sourcePassengerMinutes: Int? {
        guard let sourceStart = metadata?.sourceStart,
              let sourceEnd = metadata?.sourceEnd else {
            return nil
        }
        return max(0, Int(sourceEnd.timeIntervalSince(sourceStart) / 60))
    }

    private var groundDetail: String? {
        guard let raw = AssignmentV119MetadataCodec.humanDetail(item.detail) else {
            return nil
        }
        let aircraft = displayGroundAircraft?.uppercased()
        let cleanedRaw = perspectiveStyle
            ? raw.replacingOccurrences(
                of: #"\s*·\s*"#,
                with: " ",
                options: .regularExpression
            )
            : raw
        let lines = cleanedRaw
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { line in
                guard let aircraft else { return true }
                return normalizeAircraft(line)?.uppercased() != aircraft
                    && !line.uppercased().contains(aircraft)
            }
            .filter { $0.caseInsensitiveCompare(item.title) != .orderedSame }
        let displayedLines = lines.enumerated().map { index, line in
            guard perspectiveStyle, index < lines.count - 1 else { return line }
            return line.replacingOccurrences(
                of: #"\.\s*$"#,
                with: "",
                options: .regularExpression
            )
        }
        let value = displayedLines.joined(separator: perspectiveStyle ? " " : "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private var shouldShowGroundDuration: Bool {
        guard !perspectiveStyle else { return false }
        return !item.isAllDay
            && eventType != .dayOff
            && !item.isFlightLike
            && item.durationMinutes > 0
    }

    private var dateLabel: String {
        if item.isAllDay {
            let includedEnd = moscowCalendar.date(
                byAdding: .day,
                value: -1,
                to: item.end
            ) ?? item.start
            if moscowCalendar.isDate(item.start, inSameDayAs: includedEnd) {
                return displayDate(item.start)
            }
            return "\(displayDate(item.start)) — \(displayDate(includedEnd))"
        }

        let interval = dateInterval
        if moscowCalendar.isDate(interval.start, inSameDayAs: interval.end) {
            return displayDate(interval.start)
        }
        return "\(displayDate(interval.start)) — \(displayDate(interval.end))"
    }

    private var dateInterval: (start: Date, end: Date) {
        if perspectiveStyle, item.kind == .flight {
            return (item.start, item.end)
        }
        if perspectiveStyle,
           let sourceStart = metadata?.sourceStart,
           let sourceEnd = metadata?.sourceEnd {
            return (sourceStart, sourceEnd)
        }
        return (item.start, item.end)
    }

    private var timeRange: String? {
        guard !item.isAllDay else { return nil }

        if perspectiveStyle,
           let sourceStart = metadata?.sourceStart,
           let sourceEnd = metadata?.sourceEnd {
            return "\(clock(sourceStart)) — \(clock(sourceEnd))"
        }

        if item.kind == .passenger,
           metadata?.sourceStart != nil,
           metadata?.sourceEnd != nil {
            return nil
        }
        return "\(clock(item.start)) — \(clock(item.end))"
    }

    private var secondaryTimeRange: String? {
        nil
    }

    private func displayDate(_ date: Date) -> String {
        if !perspectiveStyle { return fullDate(date) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = moscowTimeZone
        formatter.dateFormat = "dd.MM"
        return formatter.string(from: date)
    }

    private func fullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = moscowTimeZone
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }

    private func clock(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = moscowTimeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func displayFlightNumber(_ value: String) -> String {
        let digits = value.filter(\.isNumber)
        return digits.isEmpty ? value : digits
    }

    private func expandAirport(_ value: String) -> String {
        value
            .replacingOccurrences(of: "Ш (B)", with: "Шереметьево (B)")
            .replacingOccurrences(of: "Ш (C)", with: "Шереметьево (C)")
            .replacingOccurrences(of: "Ш(B)", with: "Шереметьево (B)")
            .replacingOccurrences(of: "Ш(C)", with: "Шереметьево (C)")
    }

    private func normalizeAircraft(_ value: String?) -> String? {
        value?.replacingOccurrences(of: "-", with: "")
    }

    private func plannedMinutesMarker(in detail: String?) -> Int? {
        guard let detail,
              let start = detail.range(of: "[[AU119FLIGHT:"),
              let end = detail.range(
                of: "]]",
                range: start.upperBound..<detail.endIndex
              ) else {
            return nil
        }
        return Int(detail[start.upperBound..<end.lowerBound])
    }
}