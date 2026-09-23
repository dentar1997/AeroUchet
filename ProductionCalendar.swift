import Foundation
import CryptoKit


// MARK: - Основные настройки

let productionCalendarCountryCode =
"RU"

let productionCalendarCountryName =
"Россия"

let productionCalendarFirstYear =
2021


// MARK: - Тип дня

enum ProductionDayKind {
    
    case workday
    case shortened
    case weekend
    case holiday
    case transferredDayOff
    case transferredWorkday
}


// MARK: - Информация о дне

struct ProductionDayInfo {
    
    let kind:
    ProductionDayKind
    
    let scheduledMinutes:
    Int
    
    let title:
    String
    
    let isOfficial:
    Bool
    
    
    var isWorkingDay: Bool {
        
        scheduledMinutes > 0
    }
}


// MARK: - Состояние календаря года

enum ProductionCalendarYearState {
    
    case downloaded
    case missing
    case corrupt
}


struct ProductionCalendarYearStatus {
    
    let year:
    Int
    
    let state:
    ProductionCalendarYearState
    
    let source:
    String?
    
    let downloadedAt:
    Date?
}


// MARK: - Скачанный календарь

struct DownloadedProductionCalendarYear:
    Codable,
    Sendable {
    
    let year:
    Int
    
    let countryCode:
    String
    
    let codes:
    [UInt8]
    
    let downloadedAt:
    Date
    
    let source:
    String
    
    let checksum:
    String
}


// MARK: - Внутреннее состояние кэша

enum ProductionCalendarCacheState {
    
    case missing
    case valid
    case corrupt
}


// MARK: - Количество дней в году

func productionExpectedDaysCount(
    year: Int
) -> Int {
    
    let leap =
    year % 400 == 0
    ||
    (
        year % 4 == 0
        &&
        year % 100 != 0
    )
    
    
    return leap
    ? 366
    : 365
}


// MARK: - Контрольная сумма

private func makeProductionCalendarChecksum(
    year: Int,
    countryCode: String,
    codes: [UInt8]
) -> String {
    
    var data =
    Data(
        (
            String(year)
            +
            "|"
            +
            countryCode.uppercased()
            +
            "|"
        )
        .utf8
    )
    
    
    data.append(
        contentsOf:
            codes
    )
    
    
    let digest =
    SHA256.hash(
        data:
            data
    )
    
    
    return digest
        .map {
            
            String(
                format:
                    "%02x",
                $0
            )
        }
        .joined()
}


// MARK: - Локальная база календарей

final class ProductionCalendarCache:
    @unchecked Sendable {
    
    static let shared =
    ProductionCalendarCache()
    
    
    // V3 специально создаёт новую пустую
    // базу производственных календарей.
    //
    // Старые календари V1/V2 больше
    // не используются.
    
    private let storageKey =
    "productionCalendarDownloadedYearsV3"
    
    
    private let lock =
    NSLock()
    
    
    private var years:
    [Int: DownloadedProductionCalendarYear] = [:]
    
    
    private init() {
        
        // Удаляем только старые базы
        // производственного календаря.
        //
        // Рейсы, отсутствия и остальные
        // данные приложения не затрагиваются.
        
        UserDefaults.standard.removeObject(
            forKey:
                "productionCalendarDownloadedYearsV1"
        )
        
        
        UserDefaults.standard.removeObject(
            forKey:
                "productionCalendarDownloadedYearsV2"
        )
        
        
        load()
    }
    
    
    // MARK: Загрузка базы
    
    private func load() {
        
        guard
            let data =
                UserDefaults.standard.data(
                    forKey:
                        storageKey
                )
                
        else {
            
            years = [:]
            return
        }
        
        
        do {
            
            let array =
            try JSONDecoder()
                .decode(
                    [DownloadedProductionCalendarYear].self,
                    from:
                        data
                )
            
            
            years =
            Dictionary(
                uniqueKeysWithValues:
                    array.map {
                        
                        (
                            $0.year,
                            $0
                        )
                    }
            )
            
        } catch {
            
            print(
                "Ошибка загрузки базы производственных календарей:",
                error
            )
            
            
            years = [:]
        }
    }
    
    
    // MARK: Проверка календаря
    
    private func isValid(
        _ calendar:
        DownloadedProductionCalendarYear
    ) -> Bool {
        
        guard
            calendar.countryCode
                .uppercased()
                ==
                productionCalendarCountryCode
                
        else {
            
            return false
        }
        
        
        guard
            calendar.codes.count
                ==
                productionExpectedDaysCount(
                    year:
                        calendar.year
                )
                
        else {
            
            return false
        }
        
        
        // В обычном режиме API
        // мы используем только:
        //
        // 0 — рабочий
        // 1 — нерабочий
        // 2 — сокращённый
        
        guard
            calendar.codes
                .allSatisfy({
                    
                    $0 == 0
                    ||
                    $0 == 1
                    ||
                    $0 == 2
                })
                
        else {
            
            return false
        }
        
        
        let expectedChecksum =
        makeProductionCalendarChecksum(
            year:
                calendar.year,
            countryCode:
                calendar.countryCode,
            codes:
                calendar.codes
        )
        
        
        return
        expectedChecksum
        ==
        calendar.checksum
    }
    
    
    // MARK: Состояние года
    
    func state(
        year: Int
    ) -> ProductionCalendarCacheState {
        
        lock.lock()
        
        defer {
            lock.unlock()
        }
        
        
        guard
            let calendar =
                years[
                    year
                ]
                
        else {
            
            return .missing
        }
        
        
        return isValid(
            calendar
        )
        ? .valid
        : .corrupt
    }
    
    
    // MARK: Получить календарь
    
    func calendar(
        for year: Int
    ) -> DownloadedProductionCalendarYear? {
        
        lock.lock()
        
        defer {
            lock.unlock()
        }
        
        
        guard
            let calendar =
                years[
                    year
                ],
            
                isValid(
                    calendar
                )
                
        else {
            
            return nil
        }
        
        
        return calendar
    }
    
    
    // MARK: Сохранить календарь
    
    @discardableResult
    func save(
        year: Int,
        countryCode: String,
        codes: [UInt8],
        source: String,
        overwrite: Bool
    ) -> Bool {
        
        let normalizedCountry =
        countryCode.uppercased()
        
        
        guard
            normalizedCountry
                ==
                productionCalendarCountryCode
                
        else {
            
            return false
        }
        
        
        guard
            codes.count
                ==
                productionExpectedDaysCount(
                    year:
                        year
                )
                
        else {
            
            return false
        }
        
        
        guard
            codes.allSatisfy({
                
                $0 == 0
                ||
                $0 == 1
                ||
                $0 == 2
            })
                
        else {
            
            return false
        }
        
        
        let checksum =
        makeProductionCalendarChecksum(
            year:
                year,
            countryCode:
                normalizedCountry,
            codes:
                codes
        )
        
        
        let item =
        DownloadedProductionCalendarYear(
            year:
                year,
            countryCode:
                normalizedCountry,
            codes:
                codes,
            downloadedAt:
                Date(),
            source:
                source,
            checksum:
                checksum
        )
        
        
        lock.lock()
        
        defer {
            lock.unlock()
        }
        
        
        if
            !overwrite,
            let old =
                years[
                    year
                ],
            isValid(
                old
            ) {
            
            return true
        }
        
        
        years[
            year
        ] =
        item
        
        
        return persistLocked()
    }
    
    
    // MARK: Удалить календарь
    
    func remove(
        year: Int
    ) {
        
        lock.lock()
        
        defer {
            lock.unlock()
        }
        
        
        years.removeValue(
            forKey:
                year
        )
        
        
        _ =
        persistLocked()
    }
    
    
    // MARK: Сохранение базы
    
    private func persistLocked()
    -> Bool {
        
        do {
            
            let array =
            years.values
                .sorted {
                    
                    $0.year
                    <
                        $1.year
                }
            
            
            let data =
            try JSONEncoder()
                .encode(
                    array
                )
            
            
            UserDefaults.standard.set(
                data,
                forKey:
                    storageKey
            )
            
            
            return true
            
        } catch {
            
            print(
                "Ошибка сохранения базы производственных календарей:",
                error
            )
            
            
            return false
        }
    }
    // MARK: - Удалить все календари
    
    func deleteAllCalendars() {
        
        lock.lock()
        
        defer {
            lock.unlock()
        }
        
        
        years.removeAll()
        
        
        UserDefaults.standard.removeObject(
            forKey:
                storageKey
        )
        
        
        UserDefaults.standard.removeObject(
            forKey:
                productionCalendarLastManualActionKey
        )
        
        
        print(
            "Все производственные календари удалены."
        )
    }
}


// MARK: - Статус года

func productionCalendarYearStatus(
    year: Int
) -> ProductionCalendarYearStatus {
    
    switch ProductionCalendarCache
        .shared
        .state(
            year:
                year
        ) {
        
    case .valid:
        
        let calendar =
        ProductionCalendarCache
            .shared
            .calendar(
                for:
                    year
            )
        
        
        return ProductionCalendarYearStatus(
            year:
                year,
            state:
                    .downloaded,
            source:
                calendar?.source,
            downloadedAt:
                calendar?.downloadedAt
        )
        
        
    case .missing:
        
        return ProductionCalendarYearStatus(
            year:
                year,
            state:
                    .missing,
            source:
                nil,
            downloadedAt:
                nil
        )
        
        
    case .corrupt:
        
        return ProductionCalendarYearStatus(
            year:
                year,
            state:
                    .corrupt,
            source:
                nil,
            downloadedAt:
                nil
        )
    }
}


// MARK: - Есть ли официальный календарь

func productionCalendarSupported(
    year: Int
) -> Bool {
    
    ProductionCalendarCache
        .shared
        .state(
            year:
                year
        )
    ==
        .valid
}


// MARK: - Обязательные годы

func requiredProductionCalendarYears(
    currentYear: Int
) -> [Int] {
    
    guard
        currentYear
            >=
            productionCalendarFirstYear
            
    else {
        
        return []
    }
    
    
    return Array(
        productionCalendarFirstYear
        ...
        currentYear
    )
}


// MARK: - Проблемные годы

func productionCalendarProblemYears(
    currentYear: Int
) -> [Int] {
    
    requiredProductionCalendarYears(
        currentYear:
            currentYear
    )
    .filter {
        
        !productionCalendarSupported(
            year:
                $0
        )
    }
}


// MARK: - Сколько обязательных годов загружено

func productionCalendarLoadedRequiredCount(
    currentYear: Int
) -> Int {
    
    requiredProductionCalendarYears(
        currentYear:
            currentYear
    )
    .filter {
        
        productionCalendarSupported(
            year:
                $0
        )
    }
    .count
}


// MARK: - Федеральные праздники РФ
//
// Используются только для названия
// некоторых дней в интерфейсе.
// Состояние рабочий/выходной берётся
// именно из скачанного календаря.

private struct MonthDay:
    Hashable {
    
    let month: Int
    let day: Int
}


private func md(
    _ month: Int,
    _ day: Int
) -> MonthDay {
    
    MonthDay(
        month:
            month,
        day:
            day
    )
}


private let fixedHolidays:
[MonthDay: String] = [
    
    md(1, 1):
        "Новогодние каникулы",
    
    md(1, 2):
        "Новогодние каникулы",
    
    md(1, 3):
        "Новогодние каникулы",
    
    md(1, 4):
        "Новогодние каникулы",
    
    md(1, 5):
        "Новогодние каникулы",
    
    md(1, 6):
        "Новогодние каникулы",
    
    md(1, 7):
        "Рождество",
    
    md(1, 8):
        "Новогодние каникулы",
    
    md(2, 23):
        "23 февраля",
    
    md(3, 8):
        "8 марта",
    
    md(5, 1):
        "1 мая",
    
    md(5, 9):
        "9 мая",
    
    md(6, 12):
        "12 июня",
    
    md(11, 4):
        "4 ноября"
]


// MARK: - Скачанный календарь

private func downloadedProductionDayInfo(
    date: Date,
    month: Int,
    day: Int,
    weekday: Int,
    calendar:
    DownloadedProductionCalendarYear
) -> ProductionDayInfo? {
    
    guard
        let ordinal =
            moscowCalendar.ordinality(
                of:
                        .day,
                in:
                        .year,
                for:
                    date
            )
            
    else {
        
        return nil
    }
    
    
    let index =
    ordinal - 1
    
    
    guard
        index >= 0,
        index < calendar.codes.count
            
    else {
        
        return nil
    }
    
    
    let code =
    calendar.codes[
        index
    ]
    
    
    let key =
    md(
        month,
        day
    )
    
    
    let weekend =
    weekday == 1
    ||
    weekday == 7
    
    
    switch code {
        
        // Рабочий
        
    case 0:
        
        if weekend {
            
            return ProductionDayInfo(
                kind:
                        .transferredWorkday,
                scheduledMinutes:
                    432,
                title:
                    "Рабочий день по переносу",
                isOfficial:
                    true
            )
        }
        
        
        return ProductionDayInfo(
            kind:
                    .workday,
            scheduledMinutes:
                432,
            title:
                "Рабочий день",
            isOfficial:
                true
        )
        
        
        // Выходной
        
    case 1:
        
        if let holiday =
            fixedHolidays[
                key
            ] {
            
            return ProductionDayInfo(
                kind:
                        .holiday,
                scheduledMinutes:
                    0,
                title:
                    holiday,
                isOfficial:
                    true
            )
        }
        
        
        if weekend {
            
            return ProductionDayInfo(
                kind:
                        .weekend,
                scheduledMinutes:
                    0,
                title:
                    "Выходной",
                isOfficial:
                    true
            )
        }
        
        
        return ProductionDayInfo(
            kind:
                    .transferredDayOff,
            scheduledMinutes:
                0,
            title:
                "Перенесённый выходной",
            isOfficial:
                true
        )
        
        
        // Сокращённый рабочий день
        
    case 2:
        
        return ProductionDayInfo(
            kind:
                    .shortened,
            scheduledMinutes:
                372,
            title:
                "Сокращённый рабочий день",
            isOfficial:
                true
        )
        
        
    default:
        
        return nil
    }
}


// MARK: - Резервный расчёт
//
// Если календарь не загружен,
// приложение не падает.
//
// Но такой день НЕ считается
// официальным производственным
// календарём.

private func fallbackProductionDayInfo(
    weekday: Int
) -> ProductionDayInfo {
    
    let weekend =
    weekday == 1
    ||
    weekday == 7
    
    
    if weekend {
        
        return ProductionDayInfo(
            kind:
                    .weekend,
            scheduledMinutes:
                0,
            title:
                "Расчётный выходной",
            isOfficial:
                false
        )
    }
    
    
    return ProductionDayInfo(
        kind:
                .workday,
        scheduledMinutes:
            432,
        title:
            "Расчётный рабочий день",
        isOfficial:
            false
    )
}


// MARK: - Главная функция дня

func productionDayInfo(
    for date: Date
) -> ProductionDayInfo {
    
    let components =
    moscowCalendar
        .dateComponents(
            [
                .year,
                .month,
                .day,
                .weekday
            ],
            from:
                date
        )
    
    
    guard
        let year =
            components.year,
        
            let month =
            components.month,
        
            let day =
            components.day,
        
            let weekday =
            components.weekday
            
    else {
        
        return ProductionDayInfo(
            kind:
                    .workday,
            scheduledMinutes:
                432,
            title:
                "Расчётный рабочий день",
            isOfficial:
                false
        )
    }
    
    
    if
        let calendar =
            ProductionCalendarCache
            .shared
            .calendar(
                for:
                    year
            ),
        
            let info =
            downloadedProductionDayInfo(
                date:
                    date,
                month:
                    month,
                day:
                    day,
                weekday:
                    weekday,
                calendar:
                    calendar
            ) {
        
        return info
    }
    
    
    return fallbackProductionDayInfo(
        weekday:
            weekday
    )
}


// MARK: - Норма дня

func productionScheduledMinutes(
    for date: Date
) -> Int {
    
    productionDayInfo(
        for:
            date
    )
    .scheduledMinutes
}


// MARK: - Норма месяца

func productionMonthlyNorm(
    month: Date
) -> Int {
    
    daysInMonth(
        month
    )
    .reduce(0) {
        
        $0
        +
        productionScheduledMinutes(
            for:
                $1
        )
    }
}


// MARK: - Норма года

func productionYearNorm(
    year: Int
) -> Int {
    
    guard
        let firstMonth =
            moscowCalendar.date(
                from:
                    DateComponents(
                        year:
                            year,
                        month:
                            1,
                        day:
                            1
                    )
            )
            
    else {
        
        return 0
    }
    
    
    var total =
    0
    
    
    for offset in 0..<12 {
        
        guard
            let month =
                moscowCalendar.date(
                    byAdding:
                            .month,
                    value:
                        offset,
                    to:
                        firstMonth
                )
                
        else {
            
            continue
        }
        
        
        total +=
        productionMonthlyNorm(
            month:
                month
        )
    }
    
    
    return total
}


// MARK: - Официальный ли месяц

func productionMonthIsOfficial(
    _ month: Date
) -> Bool {
    
    let year =
    moscowCalendar.component(
        .year,
        from:
            month
    )
    
    
    return productionCalendarSupported(
        year:
            year
    )
}


// MARK: - Последнее ручное действие

let productionCalendarLastManualActionKey =
"productionCalendarLastManualActionV3"


func productionCalendarLastManualActionDate()
-> Date? {
    
    UserDefaults.standard.object(
        forKey:
            productionCalendarLastManualActionKey
    )
    as? Date
}
