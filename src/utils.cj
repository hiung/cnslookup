package cnslookup

import std.env.*
import stdx.encoding.url.*
import dnsmsg.*

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
    println("Questions Section:")
    for (question in msg.questions) {
        println("   ${question.name} ${getTypeName(question.qType)} ${getClassName(question.qClass)}")
    }
    println("Answers Section:")
    for (answer in msg.answers) {
        println(
            "   ${answer.name} ${getTypeName(answer.rType)} ${getClassName(answer.rClass)} ${answer.ttl} ${answer.rData}")
    }
}