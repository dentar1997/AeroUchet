import Foundation
import UIKit
import Vision
import AVFoundation


enum WorkPlanMediaImportError: LocalizedError {
    case unreadableImage
    case unreadableVideo
    case noEvents

    var errorDescription: String? {
        switch self {
        case .unreadableImage:
            return "Не удалось прочитать изображение."
        case .unreadableVideo:
            return "Не удалось прочитать видео."
        case .noEvents:
            return "На изображении или видео не удалось распознать назначения с датой и временем."
        }
    }
}


enum WorkPlanMediaImporter {
    static func parseImage(url: URL) throws -> [WorkEvent] {
        guard let image = UIImage(contentsOfFile: url.path),
              let cgImage = image.cgImage else {
            throw WorkPlanMediaImportError.unreadableImage
        }

        let lines = try recognize(cgImage: cgImage)
        let events = parseEvents(lines: lines)
        guard !events.isEmpty else {
            throw WorkPlanMediaImportError.noEvents
        }
        return events
    }

    static func parseVideo(url: URL) throws -> [WorkEvent] {
        let asset = AVURLAsset(url: url)
        let duration = CMTimeGetSeconds(asset.duration)
        guard duration.isFinite, duration > 0 else {
            throw WorkPlanMediaImportError.unreadableVideo
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.20, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.20, preferredTimescale: 600)

        let step = max(0.75, duration / 140.0)
        var second = 0.0
        var allEvents: [WorkEvent] = []
        var frameCount = 0

        while second <= duration, frameCount < 160 {
            let time = CMTime(seconds: second, preferredTimescale: 600)
            if let image = try? generator.copyCGImage(at: time, actualTime: nil),
               let lines = try? recognize(cgImage: image) {
                allEvents.append(contentsOf: parseEvents(lines: lines))
            }
            second += step
            frameCount += 1
        }

        let unique = removeDuplicates(allEvents)
        guard !unique.isEmpty else {
            throw WorkPlanMediaImportError.noEvents
        }
        return unique
    }

    private static func recognize(cgImage: CGImage) throws -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["ru-RU", "en-US"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        let observations = request.results ?? []
        return observations
            .compactMap { observation -> (String, CGFloat, CGFloat)? in
                guard let text = observation.topCandidates(1).first?.string else {
                    return nil
                }
                return (
                    text.trimmingCharacters(in: .whitespacesAndNewlines),
                    observation.boundingBox.midY,
                    observation.boundingBox.minX
                )
            }
            .sorted {
                if abs($0.1 - $1.1) < 0.012 {
                    return $0.2 < $1.2
                }
                return $0.1 > $1.1
            }
            .map(\.0)
            .filter { !$0.isEmpty }
    }

    private static func parseEvents(lines: [String]) -> [WorkEvent] {
        guard !lines.isEmpty else { return [] }

        var candidates: [WorkEvent] = []
        for startIndex in lines.indices {
            for length in 1...min(4, lines.count - startIndex) {
                let text = lines[startIndex..<(startIndex + length)]
                    .joined(separator: " ")
                if let event = parseEvent(text) {
                    candidates.append(event)
                }
            }
        }
        return removeDuplicates(candidates)
    }

    private static func parseEvent(_ text: String) -> WorkEvent? {
        guard let dateGroups = firstCapture(
            in: text,
            pattern: #"\b(\d{1,2})[./](\d{1,2})(?:[./](\d{2,4}))?\b"#
        ),
        dateGroups.count >= 3,
        let day = Int(dateGroups[1]),
        let month = Int(dateGroups[2]) else {
            return nil
        }

        let timeMatches = allMatches(
            in: text,
            pattern: #"\b(?:[01]?\d|2[0-3])[:.][0-5]\d\b"#
        )
        guard timeMatches.count >= 2 else { return nil }

        var year = moscowCalendar.component(.year, from: Date())
        if dateGroups.count > 3, !dateGroups[3].isEmpty, let parsedYear = Int(dateGroups[3]) {
            year = parsedYear < 100 ? 2000 + parsedYear : parsedYear
        }

        var components = DateComponents()
        components.timeZone = moscowTimeZone
        components.year = year
        components.month = month
        components.day = day
        guard let date = moscowCalendar.date(from: components) else { return nil }

        let startTime = normalizeTime(timeMatches[0])
        let endTime = normalizeTime(timeMatches[1])
        guard parsedDate(date: formatDate(date), time: startTime) != nil,
              parsedDate(date: formatDate(date), time: endTime) != nil else {
            return nil
        }

        let title = cleanedTitle(
            text,
            dateText: dateGroups[0],
            firstTime: timeMatches[0],
            secondTime: timeMatches[1]
        )
        guard title.count >= 3 else { return nil }

        return WorkEvent(
            date: formatDate(date),
            type: classify(title),
            startTime: startTime,
            endTime: endTime,
            note: title
        )
    }

    private static func classify(_ title: String) -> WorkEventType {
        let value = title.lowercased()
        if value.contains("резерв") && value.contains("дом") {
            return .homeReserve
        }
        if value.contains("резерв") {
            return .reserve
        }
        if value.contains("тренаж") || value.contains("ктс") {
            return .simulator
        }
        return .appearance
    }

    private static func cleanedTitle(
        _ text: String,
        dateText: String,
        firstTime: String,
        secondTime: String
    ) -> String {
        text
            .replacingOccurrences(of: dateText, with: " ")
            .replacingOccurrences(of: firstTime, with: " ")
            .replacingOccurrences(of: secondTime, with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: " -–—•,;"))
    }

    private static func normalizeTime(_ value: String) -> String {
        let replaced = value.replacingOccurrences(of: ".", with: ":")
        let parts = replaced.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else {
            return replaced
        }
        return String(format: "%02d:%02d", hour, minute)
    }

    private static func removeDuplicates(_ events: [WorkEvent]) -> [WorkEvent] {
        var seen = Set<String>()
        return events.filter { event in
            let key = [
                event.date,
                event.startTime,
                event.endTime,
                event.type.rawValue,
                event.note.lowercased().replacingOccurrences(of: " ", with: "")
            ].joined(separator: "|")
            return seen.insert(key).inserted
        }
    }

    private static func firstCapture(in text: String, pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = text as NSString
        guard let match = regex.firstMatch(
            in: text,
            range: NSRange(location: 0, length: ns.length)
        ) else {
            return nil
        }
        return (0..<match.numberOfRanges).map { index in
            let range = match.range(at: index)
            return range.location == NSNotFound ? "" : ns.substring(with: range)
        }
    }

    private static func allMatches(in text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return regex.matches(
            in: text,
            range: NSRange(location: 0, length: ns.length)
        ).map { ns.substring(with: $0.range) }
    }
}


extension AppStore {
    func importWorkEvents(_ candidates: [WorkEvent]) -> (added: Int, duplicates: Int) {
        func key(_ event: WorkEvent) -> String {
            [
                event.date,
                event.startTime,
                event.endTime,
                event.type.rawValue,
                event.note.lowercased().replacingOccurrences(of: " ", with: "")
            ].joined(separator: "|")
        }

        var known = Set(workEvents.map(key))
        var incoming: [WorkEvent] = []
        for candidate in candidates where known.insert(key(candidate)).inserted {
            incoming.append(candidate)
        }
        if !incoming.isEmpty {
            workEvents = incoming + workEvents
        }
        return (incoming.count, candidates.count - incoming.count)
    }
}
