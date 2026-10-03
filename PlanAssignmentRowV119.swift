import SwiftUI


struct PlanAssignmentRowV119: View {
    let item: AssignmentPlanItem
    var status: String?
    var statusColor: Color = .secondary
    var conflictText: String?

    @ObservedObject private var appearanceStore = AssignmentAppearanceStore.shared

    private var metadata: AssignmentV119Metadata? {
        AssignmentV119MetadataCodec.metadata(from: item.detail)
    }

    private var eventType: AssignmentEventType {
        AssignmentEventType.resolve(item)
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

                if metadata?.linkedGroupID != nil {
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

                if metadata?.linkedGroupID != nil {
                    Label("Связанное событие", systemImage: "link")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let conflictText {
                    Label(conflictText, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(dateLabel)
                    .font(.caption)
                    .foregroundStyle(conflictText == nil ? Color.secondary : Color.red)
                    .multilineTextAlignment(.trailing)

                if let timeRange {
                    Text(timeRange)
                        .font(.caption.monospacedDigit())
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
        .padding(.horizontal, conflictText == nil ? 0 : 8)
        .background {
            if conflictText != nil {
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
                Label(
                    "Продолжительность полётной смены уменьшить на \(timeText(reduction))",
                    systemImage: "arrow.down.circle"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
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
                .font(.caption2.weight(.bold))
                .foregroundStyle(iconStyle.color.color)

            if let sourceStart = metadata?.sourceStart,
               let sourceEnd = metadata?.sourceEnd {
                Text("\(clock(sourceStart)) — \(clock(sourceEnd))")
                    .font(.caption.monospacedDigit())
            }

            if let sourceMinutes = sourcePassengerMinutes,
               let movement = metadata?.passengerMovementMinutes {
                Text(
                    "Перемещение в качестве пассажира: \(timeText(sourceMinutes)) + 0:40 = \(timeText(movement))"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            } else if let movement = metadata?.passengerMovementMinutes {
                Text("Перемещение в качестве пассажира: \(timeText(movement))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let waiting = metadata?.waitingMinutes, waiting > 0 {
                Text("Время ожидания: \(timeText(waiting))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let total = metadata?.linkedSequenceMinutes, total > 0 {
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
            Text(item.title)
                .font(.subheadline.weight(.semibold))

            if let detail = AssignmentV119MetadataCodec.humanDetail(item.detail),
               !detail.isEmpty,
               detail.caseInsensitiveCompare(item.title) != .orderedSame {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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
        if let departure = leg.departure,
           let arrival = leg.arrival {
            parts.append("\(departure) → \(arrival)")
        }
        if let aircraft = leg.aircraft, !aircraft.isEmpty {
            parts.append(aircraft)
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
        let basis = metadata?.passengerBasis?.uppercased() ?? "ПО ЗАДАНИЮ"
        return "ПЕРЕЛЁТ ПАССАЖИРОМ \(basis)"
    }

    private var sourcePassengerMinutes: Int? {
        guard let sourceStart = metadata?.sourceStart,
              let sourceEnd = metadata?.sourceEnd else {
            return nil
        }
        return max(0, Int(sourceEnd.timeIntervalSince(sourceStart) / 60))
    }

    private var shouldShowGroundDuration: Bool {
        !item.isAllDay
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
                return fullDate(item.start)
            }
            return "\(fullDate(item.start)) — \(fullDate(includedEnd))"
        }

        let start = displayIntervalStart
        let end = displayIntervalEnd
        if moscowCalendar.isDate(start, inSameDayAs: end) {
            return fullDate(start)
        }
        return "\(fullDate(start)) — \(fullDate(end))"
    }

    private var timeRange: String? {
        guard !item.isAllDay else { return nil }
        // Для пассажирского перемещения исходное время вылета/прилёта уже
        // показано в теле карточки. Справа оставляем только дату, чтобы не
        // дублировать расчётное начало за 40 минут до вылета.
        if item.kind == .passenger,
           metadata?.sourceStart != nil,
           metadata?.sourceEnd != nil {
            return nil
        }
        return "\(clock(displayIntervalStart)) — \(clock(displayIntervalEnd))"
    }

    private var displayIntervalStart: Date {
        if item.kind == .passenger,
           let sourceStart = metadata?.sourceStart {
            return sourceStart
        }
        return item.start
    }

    private var displayIntervalEnd: Date {
        if item.kind == .passenger,
           let sourceEnd = metadata?.sourceEnd {
            return sourceEnd
        }
        return item.end
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
        return digits.isEmpty ? value : "SU \(digits)"
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
