//
//  BarcodeModules.swift
//  RockLog
//
//  Code 39 and EAN-13 are not Core Image generators. These module strings
//  are the bars the custom renderer draws. 1 is black, 0 is white.
//

import Foundation

nonisolated enum BarcodeModules {
    /// Code 39, with the required start and stop asterisks. Nil when a character is outside the set.
    static func code39(_ raw: String) -> String? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !text.isEmpty else { return nil }
        var modules = ""
        let symbols = ["*"] + text.map(String.init) + ["*"]
        for (index, symbol) in symbols.enumerated() {
            guard let pattern = code39Patterns[symbol] else { return nil }
            modules += expand(pattern)
            if index < symbols.count - 1 {
                modules += "0"
            }
        }
        return modules
    }

    /// 12 digits get a check digit. 13 digits must already include the right check digit.
    static func ean13(_ raw: String) -> String? {
        let digits = raw.filter(\.isNumber)
        let twelve: String
        if digits.count == 12 {
            guard let check = ean13CheckDigit(twelve: digits) else { return nil }
            twelve = digits + String(check)
        } else if digits.count == 13 {
            let body = String(digits.prefix(12))
            guard let check = ean13CheckDigit(twelve: body), String(check) == String(digits.suffix(1)) else {
                return nil
            }
            twelve = digits
        } else {
            return nil
        }
        let chars = Array(twelve)
        guard let first = chars.first?.wholeNumberValue,
              ean13Parity.indices.contains(first)
        else { return nil }
        let parity = ean13Parity[first]
        var modules = "101"
        for index in 1..<7 {
            guard let value = chars[index].wholeNumberValue else { return nil }
            let mark = parity[parity.index(parity.startIndex, offsetBy: index - 1)]
            let table = mark == "G" ? ean13G : ean13L
            modules += table[value]
        }
        modules += "01010"
        for index in 7..<13 {
            guard let value = chars[index].wholeNumberValue else { return nil }
            modules += ean13R[value]
        }
        modules += "101"
        return modules
    }

    static func ean13CheckDigit(twelve: String) -> Int? {
        guard twelve.count == 12, twelve.allSatisfy(\.isNumber) else { return nil }
        var sum = 0
        for (index, character) in twelve.enumerated() {
            let digit = character.wholeNumberValue ?? 0
            sum += (index % 2 == 0) ? digit : digit * 3
        }
        return (10 - (sum % 10)) % 10
    }

    private static func expand(_ pattern: String) -> String {
        var modules = ""
        for (index, mark) in pattern.enumerated() {
            let width = mark == "w" ? 3 : 1
            modules += String(repeating: index.isMultiple(of: 2) ? "1" : "0", count: width)
        }
        return modules
    }

    private static let code39Patterns: [String: String] = [
        "*": "nwnnwnwnn",
        "0": "nnnwwnwnn",
        "1": "wnnwnnnnw",
        "2": "nnwwnnnnw",
        "3": "wnwwnnnnn",
        "4": "nnnwwnnnw",
        "5": "wnnwwnnnn",
        "6": "nnwwwnnnn",
        "7": "nnnwnnwnw",
        "8": "wnnwnnwnn",
        "9": "nnwwnnwnn",
        "A": "wnnnnwnnw",
        "B": "nnwnnwnnw",
        "C": "wnwnnwnnn",
        "D": "nnnnwwnnw",
        "E": "wnnnwwnnn",
        "F": "nnwnwwnnn",
        "G": "nnnnnwwnw",
        "H": "wnnnnwwnn",
        "I": "nnwnnwwnn",
        "J": "nnnnwwwnn",
        "K": "wnnnnnnww",
        "L": "nnwnnnnww",
        "M": "wnwnnnnwn",
        "N": "nnnnwnnww",
        "O": "wnnnwnnwn",
        "P": "nnwnwnnwn",
        "Q": "nnnnnnwww",
        "R": "wnnnnnwwn",
        "S": "nnwnnnwwn",
        "T": "nnnnwnwwn",
        "U": "wwnnnnnnw",
        "V": "nwwnnnnnw",
        "W": "wwwnnnnnn",
        "X": "nwnnwnnnw",
        "Y": "wwnnwnnnn",
        "Z": "nwwnwnnnn",
        "-": "nwnnnnwnw",
        ".": "wwnnnnwnn",
        " ": "nwwnnnwnn",
        "$": "nwnwnwnnn",
        "/": "nwnwnnnwn",
        "+": "nwnnnwnwn",
        "%": "nnnwnwnwn",
    ]

    private static let ean13L = [
        "0001101", "0011001", "0010011", "0111101", "0100011",
        "0110001", "0101111", "0111011", "0110111", "0001011",
    ]
    private static let ean13G = [
        "0100111", "0110011", "0011011", "0100001", "0011101",
        "0111001", "0000101", "0010001", "0001001", "0010111",
    ]
    private static let ean13R = [
        "1110010", "1100110", "1101100", "1000010", "1011100",
        "1001110", "1010000", "1000100", "1001000", "1110100",
    ]
    /// First digit selects L/G for the next six digits.
    private static let ean13Parity = [
        "LLLLLL", "LLGLGG", "LLGGLG", "LLGGGL", "LGLLGG",
        "LGGLLG", "LGGGLL", "LGLGLG", "LGLGGL", "LGGLGL",
    ]
}
