package cnslookup

import std.regex.*
import stdx.encoding.url.*
import dnsmsg.*

const schemeRegex = #"(?<scheme>[a-zA-Z]+):\/\/"#
const domainRegex = #"(?<domain>(([0-9a-zA-Z]+[-])*[0-9a-zA-Z]+\.)+[a-zA-Z]{2, 22})"#
const ipv4Regex = #"(?<ipv4>((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))"#
const ipv6Regex = #"(?<ipv6>\[((([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4})|(([0-9a-fA-F]{1,4}:){6}:[0-9a-fA-F]{1,4})|(([0-9a-fA-F]{1,4}:){5}(:[0-9a-fA-F]{1,4}){1,2})|(([0-9a-fA-F]{1,4}:){4}(:[0-9a-fA-F]{1,4}){1,3})|(([0-9a-fA-F]{1,4}:){3}(:[0-9a-fA-F]{1,4}){1,4})|(([0-9a-fA-F]{1,4}:){2}(:[0-9a-fA-F]{1,4}){1,5})|([0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6}))|(:((:[0-9a-fA-F]{1,4}){1,7})))\])"#
const portRegex = #":(?<port>[0-9]|[1-9]\d|[1-9]\d{2}|[1-9]\d{3}|[1-5]\d{4}|6[0-4]\d{3}|65[0-4]\d{2}|655[0-2]\d|6553[0-5])"#
const pathRegex = #"(?<path>((\/(?!\/))[^\s\/\\:]*)*)"#

func domainValidator(domain: String): ?Name {
    let r = Regex("^${domainRegex}$")
    if (r.matches(domain)) {
        return Name(domain)
    }
    return None
}

func serverURLValidator(str: String): ?URL {
    let r = Regex("^(${schemeRegex})?(${domainRegex}|${ipv4Regex}|${ipv6Regex})(${portRegex})?${pathRegex}$")
    if (let Some(m) <- r.find(str, group: true)) {
        var matchedURL = m.matchString()
        let scheme = m.matchString("scheme")

        if (scheme == "" || scheme == "udp" || scheme == "tcp" || scheme == "tls") {
            let path = m.matchString("path")
            if (path != "") {
                return None // Path is not allowed for udp, tcp, or tls schemes
            }

            let domain = m.matchString("domain")
            if (domain != "") {
                matchedURL = replaceDomainWithIP(matchedURL, "") ?? return None
            }

            if (scheme == "") {
                matchedURL = "udp://" + matchedURL // Default to udp if no scheme is provided
            }

            let port = m.matchString("port")
            if (port == "") {
                if (scheme == "tls") {
                    matchedURL += ":853" // Default port for DNS over TLS
                } else {
                    matchedURL += ":53" // Default port for DNS
                }
            }
        }
        return URL.parse(matchedURL)
    }
    return None
}

func replaceDomainWithIP(input: String, ip: String): ?String {
    let r = Regex("${domainRegex}")
    if (r.matches(input)) {
        return r.replace(input, ip)
    }
    return None
}
