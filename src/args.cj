package cnslookup

import std.argopt.*
import dnsmsg.*

func parseArgs(args: Array<String>): (String, String, String) {
    let argSpecs = [Long("type", RequiredValue)]
    let result = parseArguments(args, argSpecs)
    let domainStr = result.nonOptions[0]
    let serverStr = result.nonOptions[1]
    let typeStr = result.options.get("type") ?? "A"
    return (domainStr, serverStr, typeStr)
}
