import Foundation

struct AirportInfo: Hashable {
    let iata: String
    let icao: String
    /// Как показывать: город, а у московских аэропортов — название аэропорта.
    let name: String
    /// Город для поиска («Москва» находит Шереметьево, Домодедово, Внуково, Жуковский).
    let city: String
    let aliases: [String]

    init(
        _ iata: String,
        _ icao: String,
        _ name: String,
        city: String? = nil,
        aliases: [String] = []
    ) {
        self.iata = iata
        self.icao = icao
        self.name = name
        self.city = city ?? name
        self.aliases = aliases
    }

    /// Подходит ли аэропорт под строку поиска (название, город, коды).
    func matches(_ query: String) -> Bool {
        name.localizedCaseInsensitiveContains(query)
            || city.localizedCaseInsensitiveContains(query)
    }
}

enum AirportDatabase {
    // Локальный офлайн-справочник аэропортов: история рейсов и сеть Аэрофлота
    // (07.10). Принимает IATA и ICAO. Правило показа (Денис 07.10): название
    // по городу, кроме московских аэропортов; терминал показывается только
    // у исторических Шереметьево D/E/F, в данных он сохраняется.
    // Если ICAO не уверен — вместо него стоит IATA.
    static let airports: [AirportInfo] = [
        AirportInfo("AAQ", "URKA", "Анапа"),
        AirportInfo("ABA", "UNAA", "Абакан"),
        AirportInfo("ADA", "LTAF", "Адана"),
        AirportInfo("ADB", "LTBJ", "Измир"),
        AirportInfo("AER", "URSS", "Сочи"),
        AirportInfo("AKX", "UATT", "Актобе"),
        AirportInfo("ALA", "UAAA", "Алматы"),
        AirportInfo("AMS", "EHAM", "Амстердам"),
        AirportInfo("ARH", "ULAA", "Архангельск"),
        AirportInfo("ASB", "UTAA", "Ашхабад"),
        AirportInfo("ASF", "URWA", "Астрахань"),
        AirportInfo("AUH", "OMAA", "Абу-Даби"),
        AirportInfo("AYT", "LTAI", "Анталья"),
        AirportInfo("AZN", "AZN", "Андижан"),
        AirportInfo("BAH", "OBBI", "Бахрейн"),
        AirportInfo("BAX", "UNBB", "Барнаул"),
        AirportInfo("BCN", "LEBL", "Барселона"),
        AirportInfo("BEG", "LYBE", "Белград"),
        AirportInfo("BHK", "UZSB", "Бухара", aliases: ["UTSB"]),
        AirportInfo("BJV", "LTFE", "Бодрум"),
        AirportInfo("BKK", "VTBS", "Бангкок"),
        AirportInfo("BOM", "VABB", "Мумбаи"),
        AirportInfo("BQS", "UHBB", "Благовещенск"),
        AirportInfo("BSZ", "UAFM", "Бишкек", aliases: ["UCFM"]),
        AirportInfo("BTK", "UIBB", "Братск"),
        AirportInfo("BUS", "UGSB", "Батуми"),
        AirportInfo("BZK", "UUBP", "Брянск"),
        AirportInfo("CAI", "HECA", "Каир"),
        AirportInfo("CAN", "ZGGG", "Гуанчжоу"),
        AirportInfo("CCC", "MUCC", "Кайо-Коко"),
        AirportInfo("CEE", "ULWC", "Череповец"),
        AirportInfo("CEK", "USCC", "Челябинск"),
        AirportInfo("CIT", "UAII", "Шымкент"),
        AirportInfo("CMB", "VCBI", "Коломбо"),
        AirportInfo("COV", "LTDB", "Адана"),
        AirportInfo("CSY", "UWKS", "Чебоксары"),
        AirportInfo("CTU", "ZUUU", "Чэнду"),
        AirportInfo("CXR", "VVCR", "Камрань"),
        AirportInfo("DAD", "VVDN", "Дананг"),
        AirportInfo("DEL", "VIDP", "Дели"),
        AirportInfo("DLM", "LTBS", "Даламан"),
        AirportInfo("DMB", "UADD", "Тараз"),
        AirportInfo("DME", "UUDD", "Домодедово", city: "Москва"),
        AirportInfo("DMK", "VTBD", "Бангкок"),
        AirportInfo("DOH", "OTHH", "Доха"),
        AirportInfo("DPS", "WADD", "Денпасар"),
        AirportInfo("DWC", "OMDW", "Дубай"),
        AirportInfo("DXB", "OMDB", "Дубай"),
        AirportInfo("DYR", "UHMA", "Анадырь"),
        AirportInfo("DYU", "UTDD", "Душанбе"),
        AirportInfo("EGO", "UUOB", "Белгород"),
        AirportInfo("EIK", "URKE", "Ейск"),
        AirportInfo("ESB", "LTAC", "Анкара"),
        AirportInfo("ESL", "URWI", "Элиста"),
        AirportInfo("EVN", "UDYZ", "Ереван"),
        AirportInfo("EYK", "USHQ", "Белоярский"),
        AirportInfo("FEG", "FEG", "Фергана"),
        AirportInfo("FRU", "UAFM", "Бишкек", aliases: ["UCFM"]),
        AirportInfo("GDX", "UHMM", "Магадан"),
        AirportInfo("GDZ", "URKG", "Геленджик"),
        AirportInfo("GNJ", "UBBG", "Гянджа"),
        AirportInfo("GOI", "VOGO", "Гоа"),
        AirportInfo("GOJ", "UWGG", "Нижний Новгород"),
        AirportInfo("GOX", "VOGA", "Гоа"),
        AirportInfo("GRV", "URMG", "Грозный"),
        AirportInfo("GSV", "UWSG", "Саратов"),
        AirportInfo("GUW", "UATG", "Атырау"),
        AirportInfo("GYD", "UBBB", "Баку"),
        AirportInfo("GZP", "LTFG", "Газипаша"),
        AirportInfo("HAN", "VVNB", "Ханой"),
        AirportInfo("HAV", "MUHA", "Гавана"),
        AirportInfo("HBE", "HEBA", "Александрия"),
        AirportInfo("HGH", "ZSHC", "Ханчжоу"),
        AirportInfo("HKG", "VHHH", "Гонконг"),
        AirportInfo("HKT", "VTSP", "Пхукет"),
        AirportInfo("HMA", "USHH", "Ханты-Мансийск"),
        AirportInfo("HRB", "ZYHB", "Харбин"),
        AirportInfo("HRG", "HEGN", "Хургада"),
        AirportInfo("HTA", "UIAA", "Чита"),
        AirportInfo("IAR", "UUDL", "Ярославль"),
        AirportInfo("ICN", "RKSI", "Сеул"),
        AirportInfo("IGT", "URMS", "Магас"),
        AirportInfo("IJK", "USII", "Ижевск"),
        AirportInfo("IKA", "OIIE", "Тегеран"),
        AirportInfo("IKT", "UIII", "Иркутск"),
        AirportInfo("IST", "LTFM", "Стамбул"),
        AirportInfo("IWA", "UUBI", "Иваново"),
        AirportInfo("JED", "OEJN", "Джидда"),
        AirportInfo("JOK", "UWKJ", "Йошкар-Ола"),
        AirportInfo("KEJ", "UNEE", "Кемерово"),
        AirportInfo("KGD", "UMKK", "Калининград"),
        AirportInfo("KGF", "UAKK", "Караганда"),
        AirportInfo("KGP", "USRK", "Когалым"),
        AirportInfo("KHV", "UHHH", "Хабаровск"),
        AirportInfo("KIV", "LUKK", "Кишинёв"),
        AirportInfo("KJA", "UNKL", "Красноярск"),
        AirportInfo("KLF", "UUBC", "Калуга"),
        AirportInfo("KRO", "USUU", "Курган"),
        AirportInfo("KRR", "URKK", "Краснодар"),
        AirportInfo("KSN", "UAUU", "Костанай"),
        AirportInfo("KSQ", "KSQ", "Карши"),
        AirportInfo("KUF", "UWWW", "Самара"),
        AirportInfo("KUL", "WMKK", "Куала-Лумпур"),
        AirportInfo("KUT", "UGKO", "Кутаиси"),
        AirportInfo("KVX", "USKK", "Киров"),
        AirportInfo("KXK", "UHKK", "Комсомольск-на-Амуре"),
        AirportInfo("KVK", "ULMK", "Апатиты"),
        AirportInfo("KYZ", "UNKY", "Кызыл"),
        AirportInfo("KZN", "UWKD", "Казань"),
        AirportInfo("KZO", "UAOO", "Кызылорда"),
        AirportInfo("LBD", "UTDL", "Худжанд"),
        AirportInfo("LED", "ULLI", "Санкт-Петербург"),
        AirportInfo("LJU", "LJLJ", "Любляна"),
        AirportInfo("LPK", "UUOL", "Липецк"),
        AirportInfo("LWN", "UDSG", "Гюмри"),
        AirportInfo("MCT", "OOMS", "Маскат"),
        AirportInfo("MCX", "URML", "Махачкала"),
        AirportInfo("MJZ", "UERR", "Мирный"),
        AirportInfo("MLE", "VRMM", "Мале"),
        AirportInfo("MMK", "ULMM", "Мурманск"),
        AirportInfo("MQF", "USCM", "Магнитогорск"),
        AirportInfo("MRU", "FIMP", "Маврикий"),
        AirportInfo("MRV", "URMM", "Минеральные Воды"),
        AirportInfo("MSQ", "UMMS", "Минск"),
        AirportInfo("NAJ", "UBBN", "Нахичевань"),
        AirportInfo("NAL", "URMN", "Нальчик"),
        AirportInfo("NBC", "UWKE", "Нижнекамск"),
        AirportInfo("NCE", "LFMN", "Ницца"),
        AirportInfo("NCU", "NCU", "Нукус"),
        AirportInfo("NER", "UELL", "Нерюнгри"),
        AirportInfo("NFG", "USRN", "Нефтеюганск"),
        AirportInfo("NJC", "USNN", "Нижневартовск"),
        AirportInfo("NMA", "NMA", "Наманган"),
        AirportInfo("NNM", "ULAM", "Нарьян-Мар"),
        AirportInfo("NOJ", "USRO", "Ноябрьск"),
        AirportInfo("NOZ", "UNWW", "Новокузнецк"),
        AirportInfo("NQZ", "UACC", "Астана", aliases: ["TSE"]),
        AirportInfo("NSK", "UOOO", "Норильск"),
        AirportInfo("NUX", "USMU", "Новый Уренгой"),
        AirportInfo("NVI", "UZSA", "Навои", aliases: ["UTSA"]),
        AirportInfo("NYM", "USMM", "Надым"),
        AirportInfo("OEL", "UUOR", "Орёл"),
        AirportInfo("OGZ", "URMO", "Владикавказ"),
        AirportInfo("OMS", "UNOO", "Омск"),
        AirportInfo("OSS", "UCFO", "Ош"),
        AirportInfo("OSW", "UWOR", "Орск"),
        AirportInfo("OVB", "UNNT", "Новосибирск"),
        AirportInfo("OVS", "USHS", "Советский"),
        AirportInfo("PEE", "USPP", "Пермь"),
        AirportInfo("PEK", "ZBAA", "Пекин"),
        AirportInfo("PES", "ULPB", "Петрозаводск"),
        AirportInfo("PEZ", "UWPP", "Пенза"),
        AirportInfo("PKC", "UHPP", "Петропавловск-Камчатский"),
        AirportInfo("PKV", "ULOO", "Псков"),
        AirportInfo("PKX", "ZBAD", "Пекин"),
        AirportInfo("PLX", "UASS", "Семей"),
        AirportInfo("PQC", "VVPQ", "Фукуок"),
        AirportInfo("PRG", "LKPR", "Прага"),
        AirportInfo("PVG", "ZSPD", "Шанхай"),
        AirportInfo("PWQ", "UASP", "Павлодар"),
        AirportInfo("REN", "UWOO", "Оренбург"),
        AirportInfo("RGK", "UNBG", "Горно-Алтайск"),
        AirportInfo("RKT", "OMRK", "Рас-эль-Хайма"),
        AirportInfo("ROV", "URRP", "Ростов-на-Дону"),
        AirportInfo("RUH", "OERK", "Эр-Рияд"),
        AirportInfo("SAW", "LTFJ", "Стамбул"),
        AirportInfo("SCO", "UATE", "Актау"),
        AirportInfo("SCW", "UUYY", "Сыктывкар"),
        AirportInfo("SEZ", "FSIA", "Маэ"),
        AirportInfo("SGC", "USRR", "Сургут"),
        AirportInfo("SGN", "VVTS", "Хошимин"),
        AirportInfo("SHJ", "OMSJ", "Шарджа"),
        AirportInfo("SIN", "WSSS", "Сингапур"),
        AirportInfo("SIP", "UKFF", "Симферополь", aliases: ["URFF"]),
        AirportInfo("SKD", "UZSS", "Самарканд", aliases: ["UTSS"]),
        AirportInfo("SKX", "UWPS", "Саранск"),
        AirportInfo("SLY", "USDD", "Салехард"),
        AirportInfo("SSH", "HESH", "Шарм-эш-Шейх"),
        AirportInfo("STW", "URMT", "Ставрополь"),
        AirportInfo("SUI", "UGSS", "Сухум"),
        AirportInfo("SVO", "UUEE", "Шереметьево", city: "Москва"),
        AirportInfo("SVX", "USSS", "Екатеринбург"),
        AirportInfo("SWT", "UNSS", "Стрежевой"),
        AirportInfo("SYX", "ZJSY", "Санья"),
        AirportInfo("SZX", "ZGSZ", "Шэньчжэнь"),
        AirportInfo("TAS", "UZTT", "Ташкент", aliases: ["UTTT"]),
        AirportInfo("TBS", "UGTB", "Тбилиси"),
        AirportInfo("TBW", "UUOT", "Тамбов"),
        AirportInfo("TFU", "ZUTF", "Чэнду"),
        AirportInfo("THR", "OIII", "Тегеран"),
        AirportInfo("TJM", "USTR", "Тюмень"),
        AirportInfo("TLV", "LLBG", "Тель-Авив"),
        AirportInfo("TMJ", "TMJ", "Термез"),
        AirportInfo("TOF", "UNTT", "Томск"),
        AirportInfo("UBN", "ZMCK", "Улан-Батор"),
        AirportInfo("UCT", "UUYH", "Ухта"),
        AirportInfo("UFA", "UWUU", "Уфа"),
        AirportInfo("UGC", "UGC", "Ургенч"),
        AirportInfo("UKK", "UASK", "Усть-Каменогорск"),
        AirportInfo("UKX", "UITT", "Усть-Кут"),
        AirportInfo("ULN", "ZMUB", "Улан-Батор"),
        AirportInfo("ULV", "UWLL", "Ульяновск"),
        AirportInfo("ULY", "UWLW", "Ульяновск"),
        AirportInfo("URA", "UARR", "Уральск"),
        AirportInfo("URC", "ZWWW", "Урумчи"),
        AirportInfo("URJ", "USHU", "Урай"),
        AirportInfo("URS", "UUOK", "Курск"),
        AirportInfo("USM", "VTSM", "Самуи"),
        AirportInfo("UTP", "VTBU", "Паттайя"),
        AirportInfo("UUD", "UIUU", "Улан-Удэ"),
        AirportInfo("UUS", "UHSS", "Южно-Сахалинск"),
        AirportInfo("VKO", "UUWW", "Внуково", city: "Москва"),
        AirportInfo("VKT", "UUYW", "Воркута"),
        AirportInfo("VOG", "URWW", "Волгоград"),
        AirportInfo("VOZ", "UUOO", "Воронеж"),
        AirportInfo("VRA", "MUVR", "Варадеро"),
        AirportInfo("VUS", "ULWU", "Великий Устюг"),
        AirportInfo("VVO", "UHWW", "Владивосток"),
        AirportInfo("XIY", "ZLXY", "Сиань"),
        AirportInfo("YKS", "UEEE", "Якутск"),
        AirportInfo("ZAG", "LDZA", "Загреб"),
        AirportInfo("ZIA", "UUBW", "Жуковский", city: "Москва"),
        AirportInfo("ZNZ", "HTZA", "Занзибар"),
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
        let parts = code.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true)
        let base = parts.first.map(String.init) ?? code
        let terminal = parts.count > 1 ? String(parts[1]) : nil

        guard let airport = byCode[base] else {
            return shownCode(base, terminal: terminal)
        }
        return "\(airport.name) (\(shownCode(airport.iata, terminal: terminal)))"
    }

    /// Терминал виден только у исторических Шереметьево D, E, F.
    private static func shownCode(_ iata: String, terminal: String?) -> String {
        guard iata == "SVO",
              let terminal = terminal?.trimmingCharacters(in: .whitespaces),
              ["D", "E", "F"].contains(terminal) else { return iata }
        return "\(iata)/\(terminal)"
    }

    static func isKnown(_ rawCode: String) -> Bool {
        airport(for: rawCode) != nil
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
