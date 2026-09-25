import Foundation


// MARK: - Московское время

let moscowTimeZone =
TimeZone(
    identifier: "Europe/Moscow"
)!


let moscowCalendar: Calendar = {
    
    var calendar =
    Calendar(
        identifier: .gregorian
    )
    
    
    calendar.timeZone =
    moscowTimeZone
    
    
    calendar.firstWeekday =
    2
    
    
    return calendar
}()


// MARK: - Базовые интервалы

func minutesBetween(
    _ start: Date,
    _ end: Date
) -> Int {
    
    max(
        0,
        Int(
            end.timeIntervalSince(
                start
            )
            /
            60
        )
    )
}


func signedMinutesBetween(
    _ start: Date,
    _ end: Date
) -> Int {
    
    Int(
        end.timeIntervalSince(
            start
        )
        /
        60
    )
}


func overlapMinutes(
    start1: Date,
    end1: Date,
    start2: Date,
    end2: Date
) -> Int {
    
    let start =
    max(
        start1,
        start2
    )
    
    
    let end =
    min(
        end1,
        end2
    )
    
    
    guard end > start
    else {
        return 0
    }
    
    
    return minutesBetween(
        start,
        end
    )
}


func minutesInDay(
    from start: Date,
    to end: Date,
    day: Date
) -> Int {
    
    let dayStart =
    moscowCalendar
        .startOfDay(
            for: day
        )
    
    
    let nextDay =
    moscowCalendar.date(
        byAdding: .day,
        value: 1,
        to: dayStart
    )!
    
    
    return overlapMinutes(
        start1:
            start,
        end1:
            end,
        start2:
            dayStart,
        end2:
            nextDay
    )
}


// MARK: - Ночь 22:00–06:00

func nightMinutesInDay(
    from start: Date,
    to end: Date,
    day: Date
) -> Int {
    
    let dayStart =
    moscowCalendar
        .startOfDay(
            for: day
        )
    
    
    let sixAM =
    moscowCalendar.date(
        bySettingHour: 6,
        minute: 0,
        second: 0,
        of: dayStart
    )!
    
    
    let tenPM =
    moscowCalendar.date(
        bySettingHour: 22,
        minute: 0,
        second: 0,
        of: dayStart
    )!
    
    
    let nextDay =
    moscowCalendar.date(
        byAdding: .day,
        value: 1,
        to: dayStart
    )!
    
    
    let morning =
    overlapMinutes(
        start1:
            start,
        end1:
            end,
        start2:
            dayStart,
        end2:
            sixAM
    )
    
    
    let evening =
    overlapMinutes(
        start1:
            start,
        end1:
            end,
        start2:
            tenPM,
        end2:
            nextDay
    )
    
    
    return morning + evening
}


func nightMinutes(
    from start: Date,
    to end: Date
) -> Int {
    
    guard end > start
    else {
        return 0
    }
    
    
    var day =
    moscowCalendar
        .startOfDay(
            for: start
        )
    
    
    let lastDay =
    moscowCalendar
        .startOfDay(
            for: end
        )
    
    
    var total = 0
    
    
    while day <= lastDay {
        
        total +=
        nightMinutesInDay(
            from:
                start,
            to:
                end,
            day:
                day
        )
        
        
        day =
        moscowCalendar.date(
            byAdding: .day,
            value: 1,
            to: day
        )!
    }
    
    
    return total
}


// MARK: - Календарные дни

func dayKey(
    _ date: Date
) -> Int {
    
    let components =
    moscowCalendar
        .dateComponents(
            [
                .year,
                .month,
                .day
            ],
            from:
                date
        )
    
    
    return
    (components.year ?? 0)
    * 10000
    +
    (components.month ?? 0)
    * 100
    +
    (components.day ?? 0)
}


func touchedDays(
    from start: Date,
    to end: Date
) -> [Date] {
    
    guard end > start
    else {
        return []
    }
    
    
    var result:
    [Date] = []
    
    
    var day =
    moscowCalendar
        .startOfDay(
            for: start
        )
    
    
    let adjustedEnd =
    end.addingTimeInterval(
        -1
    )
    
    
    let lastDay =
    moscowCalendar
        .startOfDay(
            for:
                adjustedEnd
        )
    
    
    while day <= lastDay {
        
        result.append(
            day
        )
        
        
        day =
        moscowCalendar.date(
            byAdding: .day,
            value: 1,
            to: day
        )!
    }
    
    
    return result
}


// MARK: - Расчёт зачётного времени

func creditedMinutesInDay(
    start: Date,
    end: Date,
    divisor: Int,
    day: Date
) -> Int {
    
    guard divisor > 0
    else {
        return 0
    }
    
    
    let dayStart =
    moscowCalendar.startOfDay(
        for: day
    )
    
    
    let dayEnd =
    moscowCalendar.date(
        byAdding: .day,
        value: 1,
        to: dayStart
    )!
    
    
    let segmentStart =
    max(
        start,
        dayStart
    )
    
    
    let segmentEnd =
    min(
        end,
        dayEnd
    )
    
    
    guard segmentEnd > segmentStart
    else {
        return 0
    }
    
    
    if divisor == 1 {
        
        return minutesBetween(
            segmentStart,
            segmentEnd
        )
    }
    
    
    let elapsedBefore =
    minutesBetween(
        start,
        segmentStart
    )
    
    
    let elapsedAfter =
    minutesBetween(
        start,
        segmentEnd
    )
    
    
    return
    elapsedAfter / divisor
    -
    elapsedBefore / divisor
}


func creditedNightMinutesInDay(
    start: Date,
    end: Date,
    divisor: Int,
    day: Date
) -> Int {
    
    guard divisor > 0
    else {
        return 0
    }
    
    
    let rawNight =
    nightMinutesInDay(
        from:
            start,
        to:
            end,
        day:
            day
    )
    
    
    return
    rawNight
    /
    divisor
}
