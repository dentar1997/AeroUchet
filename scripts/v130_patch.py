from pathlib import Path

# Canonicalize alias IATA codes (TSE -> NQZ etc.) before comparing PDF route with schedule.
p = Path("ReferenceDataV129.swift")
text = p.read_text()
old = '''        if let slash = upper.firstIndex(of: "/") {\n            let value = String(upper[..<slash]).filter(\\.isLetter)\n            if value.count == 3 { return value }\n        }'''
new = '''        if let slash = upper.firstIndex(of: "/") {\n            let value = String(upper[..<slash]).filter(\\.isLetter)\n            if value.count == 3 { return AirportDatabase.airport(for: value)?.iata ?? value }\n        }'''
if old not in text:
    raise RuntimeError("slash airportCode block not found")
text = text.replace(old, new, 1)
old = '''            return (upper as NSString).substring(with: match.range(at: 1))'''
new = '''            let value = (upper as NSString).substring(with: match.range(at: 1))\n            return AirportDatabase.airport(for: value)?.iata ?? value'''
if old not in text:
    raise RuntimeError("parenthesized airportCode block not found")
text = text.replace(old, new, 1)
old = '''        let letters = upper.filter(\\.isLetter)\n        if letters.count == 3 { return letters }'''
new = '''        let letters = upper.filter(\\.isLetter)\n        if letters.count == 3 { return AirportDatabase.airport(for: letters)?.iata ?? letters }'''
if old not in text:
    raise RuntimeError("plain airportCode block not found")
text = text.replace(old, new, 1)
p.write_text(text)

# Use canonical flight number in the schedule identity key too, so 0010 and 10 cannot create duplicates.
p = Path("ReferenceDataV129.swift")
text = p.read_text()
old = '''            flightNumber,\n            FlightScheduleStoreV129.dayKey(validFrom),'''
new = '''            FlightScheduleStoreV129.normalizedFlightNumber(flightNumber),\n            FlightScheduleStoreV129.dayKey(validFrom),'''
if old not in text:
    raise RuntimeError("identity flight number block not found")
text = text.replace(old, new, 1)
p.write_text(text)
print("v130 canonical route/flight fixes applied")
