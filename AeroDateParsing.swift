import Foundation


// MARK: - Строгий разбор сохранённых дат и времени

let parserFormatter: DateFormatter = {
    
    let formatter =
    DateFormatter()
    
    
    formatter.locale =
    Locale(
        identifier:
            "en_US_POSIX"
    )
    
    
    formatter.timeZone =
    moscowTimeZone
    
    
    formatter.dateFormat =
    "dd.MM.yyyy HH:mm"
    
    
    formatter.isLenient =
    false
    
    
    return formatter
}()


let invalidStoredDatePlaceholder =
Date(
    timeIntervalSince1970:
        0
)


func parsedDate(
    date: String,
    time: String
) -> Date? {
    
    let source =
    "\(date) \(time)"
    
    
    guard
        let value =
            parserFormatter.date(
                from:
                    source
            )
    else {
        return nil
    }
    
    
    guard
        parserFormatter.string(
            from:
                value
        )
        ==
        source
    else {
        return nil
    }
    
    
    return value
}


/// Месяц рейса для файла истории: «06.10.2026» → «2026-10». Непонятная дата — «other».
func historyMonthKey(for date: String) -> String {
    let parts = date.split(separator: ".")
    guard parts.count == 3,
          let month = Int(parts[1]), (1...12).contains(month),
          parts[2].count == 4, let year = Int(parts[2]) else {
        return "other"
    }
    return String(format: "%04d-%02d", year, month)
}
