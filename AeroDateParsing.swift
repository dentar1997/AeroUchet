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
