package cnslookup

import std.env.*
import stdx.encoding.url.*
import dnsmsg.*

const USAGE: String = #"Usage: cnslookup [OPTIONS] <domain> <dns-server-url>
Arguments:
    <domain>            The domain name to lookup
    <dns-server-url>    The DNS server url, udp://, tcp://, tls://, https:// supported
Options:
    -h, --help          Show help message and exit
    -t, --type TYPE     Set question type for DNS query (default: A)
Examples:
    cnslookup example.com x.x.x.x
    cnslookup example.com tcp://x.x.x.x:53 --type=A"#

func exit(code: Int64, message: String): Nothing {
    println(message)
    exit(code)
}

func printServer(serverURL: URL): Unit {
    if (serverURL.scheme == "udp" || serverURL.scheme == "tcp") {
        println("DNS Server: ${serverURL}")
        return
    }
    println("DNS Server: ${serverURL}")
}

func printMessage(msg: Message): Unit {
    println("Header Section:")
    println("   Transaction ID: ${msg.header.id} ")
    println(
        "   Flags: QR: ${msg.header.flags.response} Opcode: ${msg.header.flags.opCode} AA: ${msg.header.flags.authoritative} TC: ${msg.header.flags.truncated} RD: ${msg.header.flags.recursionDesired} RA: ${msg.header.flags.recursionAvailable} RCODE: ${msg.header.flags.rCode}")
    println(
        "   Questions: ${msg.header.qdCount} Answer RRs: ${msg.header.anCount} Authority RRs: ${msg.header.nsCount} Additional RRs: ${msg.header.arCount}")
    if (!msg.questions.isEmpty()) {
        println("Questions Section:")
        for (question in msg.questions) {
            println("   ${question.name} ${getTypeName(question.qType)} ${getClassName(question.qClass)}")
        }
    }

    if (!msg.answers.isEmpty()) {
        println("Answer Section:")
        printResourceRecord(msg.answers)
    }
    if (!msg.authorities.isEmpty()) {
        println("Authority Section:")
        printResourceRecord(msg.authorities)
    }
    if (!msg.additionals.isEmpty()) {
        println("Additional Section:")
        printResourceRecord(msg.additionals)
    }
}

func printResourceRecord(rrs: Array<ResourceRecord>) {
    for (rr in rrs) {
        println("   ${rr.name} ${getTypeName(rr.rType)} ${getClassName(rr.rClass)} ${rr.ttl} ${rr.rData}")
    }
}
