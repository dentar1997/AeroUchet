import Foundation

struct AirportInfo: Hashable {
    let iata: String
    let icao: String
    let name: String
    let aliases: [String]

    init(
        _ iata: String,
        _ icao: String,
        _ name: String,
        aliases: [String] = []
    ) {
        self.iata = iata
        self.icao = icao
        self.name = name
        self.aliases = aliases
    }
}

enum AirportDatabase {
    // Локальный офлайн-справочник аэропортов.
    // Он покрывает аэропорты из импортированной истории рейсов и принимает
    // как IATA, так и ICAO. Для кодов с терминалом (например SVO/C)
    // поиск выполняется по базовому коду, а исходный суффикс сохраняется на экране.
    static let airports: [AirportInfo] = [
        AirportInfo("AAQ", "URKA", "Анапа"),
        AirportInfo("ABA", "UNAA", "Абакан"),
        AirportInfo("ADA", "LTAF", "Адана"),
        AirportInfo("AER", "URSS", "Сочи"),
        AirportInfo("ALA", "UAAA", "Алматы"),
        AirportInfo("AMS", "EHAM", "Амстердам"),
        AirportInfo("ARH", "ULAA", "Архангельск"),
        AirportInfo("ASF", "URWA", "Астрахань"),
        AirportInfo("AUH", "OMAA", "Абу-Даби"),
        AirportInfo("AYT", "LTAI", "Анталья"),
        AirportInfo("BAX", "UNBB", "Барнаул"),
        AirportInfo("BCN", "LEBL", "Барселона"),
        AirportInfo("BEG", "LYBE", "Белград"),
        AirportInfo("BHK", "UZSB", "Бухара", aliases: ["UTSB"]),
        AirportInfo("BSZ", "UAFM", "Бишкек — Манас", aliases: ["UCFM"]),
        AirportInfo("CEK", "USCC", "Челябинск"),
        AirportInfo("CIT", "UAII", "Шымкент"),
        AirportInfo("COV", "LTDB", "Чукурова"),
        AirportInfo("CSY", "UWKS", "Чебоксары"),
        AirportInfo("DEL", "VIDP", "Дели"),
        AirportInfo("DLM", "LTBS", "Даламан"),
        AirportInfo("EVN", "UDYZ", "Ереван"),
        AirportInfo("FRU", "UAFM", "Бишкек — Манас", aliases: ["UCFM"]),
        AirportInfo("GNJ", "UBBG", "Гянджа"),
        AirportInfo("GOJ", "UWGG", "Нижний Новгород"),
        AirportInfo("GRV", "URMG", "Грозный"),
        AirportInfo("GSV", "UWSG", "Саратов — Гагарин"),
        AirportInfo("GYD", "UBBB", "Баку"),
        AirportInfo("HMA", "USHH", "Ханты-Мансийск"),
        AirportInfo("IJK", "USII", "Ижевск"),
        AirportInfo("IST", "LTFM", "Стамбул"),
        AirportInfo("KGD", "UMKK", "Калининград"),
        AirportInfo("KGF", "UAKK", "Караганда"),
        AirportInfo("KHV", "UHHH", "Хабаровск"),
        AirportInfo("KJA", "UNKL", "Красноярск"),
        AirportInfo("KRR", "URKK", "Краснодар"),
        AirportInfo("KUF", "UWWW", "Самара"),
        AirportInfo("KZN", "UWKD", "Казань"),
        AirportInfo("LED", "ULLI", "Санкт-Петербург — Пулково"),
        AirportInfo("LJU", "LJLJ", "Любляна"),
        AirportInfo("LWN", "UDSG", "Гюмри — Ширак"),
        AirportInfo("MCX", "URML", "Махачкала"),
        AirportInfo("MMK", "ULMM", "Мурманск"),
        AirportInfo("MQF", "USCM", "Магнитогорск"),
        AirportInfo("MRV", "URMM", "Минеральные Воды"),
        AirportInfo("MSQ", "UMMS", "Минск"),
        AirportInfo("NAL", "URMN", "Нальчик"),
        AirportInfo("NBC", "UWKE", "Нижнекамск — Бегишево"),
        AirportInfo("NCE", "LFMN", "Ницца"),
        AirportInfo("NJC", "USNN", "Нижневартовск"),
        AirportInfo("NOZ", "UNWW", "Новокузнецк"),
        AirportInfo("NQZ", "UACC", "Астана", aliases: ["TSE"]),
        AirportInfo("NUX", "USMU", "Новый Уренгой"),
        AirportInfo("NVI", "UZSA", "Навои", aliases: ["UTSA"]),
        AirportInfo("OGZ", "URMO", "Владикавказ"),
        AirportInfo("OMS", "UNOO", "Омск"),
        AirportInfo("OSS", "UCFO", "Ош"),
        AirportInfo("OSW", "UWOR", "Орск"),
        AirportInfo("OVB", "UNNT", "Новосибирск"),
        AirportInfo("PEE", "USPP", "Пермь"),
        AirportInfo("PEZ", "UWPP", "Пенза"),
        AirportInfo("PRG", "LKPR", "Прага"),
        AirportInfo("REN", "UWOO", "Оренбург"),
        AirportInfo("RGK", "UNBG", "Горно-Алтайск"),
        AirportInfo("ROV", "URRP", "Ростов-на-Дону — Платов"),
        AirportInfo("SCO", "UATE", "Актау"),
        AirportInfo("SCW", "UUYY", "Сыктывкар"),
        AirportInfo("SGC", "USRR", "Сургут"),
        AirportInfo("SIP", "UKFF", "Симферополь", aliases: ["URFF"]),
        AirportInfo("SKD", "UZSS", "Самарканд", aliases: ["UTSS"]),
        AirportInfo("STW", "URMT", "Ставрополь"),
        AirportInfo("SVO", "UUEE", "Шереметьево"),
        AirportInfo("SVX", "USSS", "Екатеринбург"),
        AirportInfo("TAS", "UZTT", "Ташкент", aliases: ["UTTT"]),
        AirportInfo("TJM", "USTR", "Тюмень"),
        AirportInfo("TOF", "UNTT", "Томск"),
        AirportInfo("UFA", "UWUU", "Уфа"),
        AirportInfo("ULV", "UWLL", "Ульяновск"),
        AirportInfo("VOG", "URWW", "Волгоград"),
        AirportInfo("ZAG", "LDZA", "Загреб"),
        AirportInfo("ZRH", "LSZH", "Цюрих")
    ]

    private static let byCode: [String: AirportInfo] = {
        var result: [String: AirportInfo] = [:]

        for airport in airports {
            result[airport.iata] = airport
            result[airport.icao] = airport

            for alias in airport.aliases {
                result[alias] = airport
            }
        }

        return result
    }()

    static func airport(for rawCode: String) -> AirportInfo? {
        let code = normalizedCode(rawCode)
        let base = code.split(
            separator: "/",
            maxSplits: 1,
            omittingEmptySubsequences: true
        ).first.map(String.init) ?? code

        return byCode[base]
    }

    static func displayName(for rawCode: String) -> String {
        let code = normalizedCode(rawCode)

        guard let airport = airport(for: code) else {
            return code
        }

        return "\(airport.name) (\(code))"
    }

    static func routeDisplayName(_ codes: [String]) -> String {
        codes.map(displayName).joined(separator: " → ")
    }

    private static func normalizedCode(_ rawCode: String) -> String {
        rawCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }
}
