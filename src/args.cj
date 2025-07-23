package cnslookup

import std.argopt.*
import dnsmsg.*

func parseArgs(args: Array<String>): (String, String, String) {
    let argSpecs = [
        Full("type", r't', RequiredValue),
        Full("help", r'h', NoValue)
    ]
    try {
        let result = parseArguments(args, argSpecs)

        if (result.options.contains("help") || result.options.contains("h")) {
            exit(0, USAGE)
        }
        if (result.nonOptions.size == 0) {
            exit(1, "Missing arguments.\n" + USAGE)
        }
        let domainStr = result.nonOptions[0]
        let serverStr = if (result.nonOptions.size == 1) {
            "udp://114.114.114.114:53"
        } else {
            result.nonOptions[1]
        }
        let typeStr = result.options.get("type") ?? result.options.get('t') ?? "A"
        return (domainStr, serverStr, typeStr)
    } catch (e: ArgumentParseException) {
        exit(1, "${e.message}\n" + USAGE)
    }


}
