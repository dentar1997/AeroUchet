import Foundation


// MARK: - Отчёт

struct ProductionCalendarSyncReport:
    Sendable {
    
    var downloadedYears:
    [Int] = []
    
    var refreshedYears:
    [Int] = []
    
    var unavailableYears:
    [Int] = []
    
    var failedYears:
    [Int] = []
    
    var blockedByProblemYears:
    [Int] = []
}


// MARK: - Результат запроса года

private enum CalendarDownloadResult {
    
    case downloaded
    case refreshed
    case unavailable
    case failed
}


// MARK: - Загрузчик

actor ProductionCalendarUpdater {
    
    static let shared =
    ProductionCalendarUpdater()
    
    
    private init() {}
    
    
    // MARK: - Загрузка обязательных календарей
    //
    // Загружаем только отсутствующие
    // или повреждённые годы:
    //
    // 2021 ... текущий год.
    
    func downloadRequiredCalendars(
        now: Date = Date()
    ) async -> ProductionCalendarSyncReport {
        
        var report =
        ProductionCalendarSyncReport()
        
        
        let currentYear =
        moscowCalendar.component(
            .year,
            from:
                now
        )
        
        
        let problemYears =
        productionCalendarProblemYears(
            currentYear:
                currentYear
        )
        
        
        for year in problemYears {
            
            let result =
            await downloadCalendar(
                year:
                    year,
                overwrite:
                    true
            )
            
            
            apply(
                result:
                    result,
                year:
                    year,
                report:
                    &report
            )
        }
        
        
        markManualAction(
            now:
                now
        )
        
        
        return report
    }
    
    
    // MARK: - Проверка следующего года
    //
    // Перед этим ещё раз локально
    // проверяем старые календари.
    //
    // Если какой-то год повреждён
    // или отсутствует — сначала
    // пытаемся восстановить его.
    
    func checkNextYear(
        now: Date = Date()
    ) async -> ProductionCalendarSyncReport {
        
        var report =
        ProductionCalendarSyncReport()
        
        
        let currentYear =
        moscowCalendar.component(
            .year,
            from:
                now
        )
        
        
        // Сначала восстанавливаем базу,
        // если внезапно появился пропуск.
        
        let problemYears =
        productionCalendarProblemYears(
            currentYear:
                currentYear
        )
        
        
        for year in problemYears {
            
            let result =
            await downloadCalendar(
                year:
                    year,
                overwrite:
                    true
            )
            
            
            apply(
                result:
                    result,
                year:
                    year,
                report:
                    &report
            )
        }
        
        
        // После восстановления снова проверяем.
        
        let remainingProblems =
        productionCalendarProblemYears(
            currentYear:
                currentYear
        )
        
        
        guard
            remainingProblems.isEmpty
                
        else {
            
            report.blockedByProblemYears =
            remainingProblems
            
            
            markManualAction(
                now:
                    now
            )
            
            
            return report
        }
        
        
        let nextYear =
        currentYear + 1
        
        
        let result =
        await downloadCalendar(
            year:
                nextYear,
            overwrite:
                true
        )
        
        
        apply(
            result:
                result,
            year:
                nextYear,
            report:
                &report
        )
        
        
        markManualAction(
            now:
                now
        )
        
        
        return report
    }
    
    
    // MARK: - Один год
    
    private func downloadCalendar(
        year: Int,
        overwrite: Bool
    ) async -> CalendarDownloadResult {
        
        let previousWasValid =
        productionCalendarSupported(
            year:
                year
        )
        
        
        var components =
        URLComponents(
            string:
                "https://isdayoff.ru/api/getdata"
        )
        
        
        components?.queryItems = [
            
            URLQueryItem(
                name:
                    "year",
                value:
                    String(year)
            ),
            
            
            // Только Россия
            
            URLQueryItem(
                name:
                    "cc",
                value:
                    "ru"
            ),
            
            
            // Пятидневная неделя
            
            URLQueryItem(
                name:
                    "sd",
                value:
                    "0"
            ),
            
            
            // Учитываем сокращённые дни
            
            URLQueryItem(
                name:
                    "pre",
                value:
                    "1"
            )
        ]
        
        
        guard
            let url =
                components?.url
                
        else {
            
            return .failed
        }
        
        
        var request =
        URLRequest(
            url:
                url,
            cachePolicy:
                    .reloadIgnoringLocalCacheData,
            timeoutInterval:
                20
        )
        
        
        request.setValue(
            "AeroUchet-iOS/1.0",
            forHTTPHeaderField:
                "User-Agent"
        )
        
        
        do {
            
            let (
                data,
                response
            ) =
            try await URLSession
                .shared
                .data(
                    for:
                        request
                )
            
            
            guard
                let http =
                    response
                    as? HTTPURLResponse
                    
            else {
                
                return .failed
            }
            
            
            let rawText =
            String(
                data:
                    data,
                encoding:
                        .utf8
            )?
                .trimmingCharacters(
                    in:
                            .whitespacesAndNewlines
                )
            ??
            ""
            
            
            // API сообщает:
            // 101 / HTTP 404 —
            // данных на такой год ещё нет.
            
            if
                http.statusCode == 404
                    ||
                    rawText == "101" {
                
                return .unavailable
            }
            
            
            guard
                http.statusCode == 200
                    
            else {
                
                return .failed
            }
            
            
            // Другие служебные ошибки API.
            
            if
                rawText == "100"
                    ||
                    rawText == "199" {
                
                return .failed
            }
            
            
            guard
                let codes =
                    parseCodes(
                        rawText
                    )
                    
            else {
                
                return .failed
            }
            
            
            guard
                validate(
                    year:
                        year,
                    codes:
                        codes
                )
                    
            else {
                
                print(
                    "Календарь "
                    +
                    String(year)
                    +
                    " не прошёл проверку."
                )
                
                
                return .failed
            }
            
            
            let saved =
            ProductionCalendarCache
                .shared
                .save(
                    year:
                        year,
                    countryCode:
                        productionCalendarCountryCode,
                    codes:
                        codes,
                    source:
                        "isDayOff.ru • RU",
                    overwrite:
                        overwrite
                )
            
            
            guard saved
            else {
                
                return .failed
            }
            
            
            return previousWasValid
            ? .refreshed
            : .downloaded
            
        } catch {
            
            print(
                "Ошибка загрузки календаря "
                +
                String(year)
                +
                ":",
                error
            )
            
            
            return .failed
        }
    }
    
    
    // MARK: - Разбор ответа
    
    private func parseCodes(
        _ text: String
    ) -> [UInt8]? {
        
        guard
            !text.isEmpty
                
        else {
            
            return nil
        }
        
        
        var result:
        [UInt8] = []
        
        
        result.reserveCapacity(
            text.count
        )
        
        
        for character in text {
            
            switch character {
                
            case "0":
                result.append(0)
                
            case "1":
                result.append(1)
                
            case "2":
                result.append(2)
                
            default:
                
                return nil
            }
        }
        
        
        return result
    }
    
    
    // MARK: - Проверка скачанного года
    
    private func validate(
        year: Int,
        codes: [UInt8]
    ) -> Bool {
        
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
        
        
        // Проверяем, что это похоже
        // на реальный российский
        // производственный календарь,
        // а не пустой ответ.
        
        let nonWorkingDays =
        codes.filter {
            
            $0 == 1
        }
        .count
        
        
        guard
            nonWorkingDays >= 80,
            nonWorkingDays <= 160
                
        else {
            
            return false
        }
        
        
        // 1 января РФ не должно
        // быть обычным рабочим днём.
        
        guard
            codes.first == 1
                
        else {
            
            return false
        }
        
        
        return true
    }
    
    
    // MARK: - Результат в отчёт
    
    private func apply(
        result:
        CalendarDownloadResult,
        year: Int,
        report:
        inout ProductionCalendarSyncReport
    ) {
        
        switch result {
            
        case .downloaded:
            
            report.downloadedYears
                .append(
                    year
                )
            
            
        case .refreshed:
            
            report.refreshedYears
                .append(
                    year
                )
            
            
        case .unavailable:
            
            report.unavailableYears
                .append(
                    year
                )
            
            
        case .failed:
            
            report.failedYears
                .append(
                    year
                )
        }
    }
    
    
    // MARK: - Дата ручной проверки
    
    private func markManualAction(
        now: Date
    ) {
        
        UserDefaults.standard.set(
            now,
            forKey:
                productionCalendarLastManualActionKey
        )
    }
}
