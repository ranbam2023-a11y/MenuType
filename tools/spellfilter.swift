// Filters a candidate word list through the system spell checker, dropping
// anything that isn't a recognised English word (typos, foreign tokens, and
// leftovers the blocklists didn't catch).
//
// Usage: spellfilter <candidates.txt> <approved.txt>
import AppKit

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write("usage: spellfilter <in> <out>\n".data(using: .utf8)!)
    exit(2)
}

let checker = NSSpellChecker.shared
let input = try! String(contentsOfFile: args[1], encoding: .utf8)
    .split(separator: "\n")
    .map(String.init)

var approved: [String] = []
for word in input {
    let result = checker.checkSpelling(of: word, startingAt: 0, language: "en",
                                       wrap: false, inSpellDocumentWithTag: 0, wordCount: nil)
    if result.location == NSNotFound {
        approved.append(word)
    }
}

try! approved.joined(separator: "\n").write(toFile: args[2], atomically: true, encoding: .utf8)
print("  spell checker approved \(approved.count) of \(input.count)")
