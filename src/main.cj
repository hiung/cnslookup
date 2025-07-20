package cnslookup

import std.net.*
import std.io.*
import std.regex.*
import std.convert.*
import std.env.*
import stdx.encoding.url.*
import dnsmsg.*

main(args: Array<String>): Int64 {
    if (args.size < 2) {
        exit(1, "Usage: cnslookup <domain> <dns-server-url>\nExample: cnslookup example.com udp://x.x.x.x:53")
    }
    // Get the domain args[0] and server URL args[1] from command line arguments
    let domainStr = args[0]
    let serverStr = args[1]
    // Validate the domain and server URL
    let domain = domainValidator(domainStr) ?? exit(1, "Invalid domain: ${domainStr}")
    let serverURL = serverURLValidator(serverStr) ?? exit(1, "Invalid DNS server URL: ${serverStr}")
    // Make a DNS request based on the scheme of the server URL
    let respMsg = if (serverURL.scheme == "udp") {
        UdpRequest(domain, serverURL)
    } else if (serverURL.scheme == "tcp") {
        TcpRequest(domain, serverURL)
    } else if (serverURL.scheme == "tls") {
        TlsRequest(domain, serverURL)
    } else if (serverURL.scheme == "https") {
        HttpsRequest(domain, serverURL)
    } else {
        exit(1, "Unsupported scheme: ${serverURL.scheme}. Use udp://, tcp://, tls://, or https://")
    }
    // Print the response message
    printServer(serverURL)
    printMessage(respMsg)

    return 0
}

func UdpRequest(domain: Name, serverURL: URL): Message {
    let reqMsg = MessageBuilder(id: ID()).addQuestion(Question(domain, TypeA, ClassIN)).build()
    let payload = reqMsg.toBytes()

    let bytes = Array<UInt8>(512, repeat: 0)

    try (udpSocket = UdpSocket(bindAt: 0)) {
        udpSocket.sendTimeout = Duration.second * 2
        udpSocket.receiveTimeout = Duration.second * 2
        udpSocket.bind()
        udpSocket.sendTo(
            IPSocketAddress(serverURL.hostName, UInt16.parse(if (serverURL.port == "") {
                "53"
            } else {
                serverURL.port
            })), payload)
        udpSocket.receiveFrom(bytes)
    }

    let buffer = ByteBuffer(bytes)
    return Message.fromBytes(buffer)
}

func TcpRequest(domain: Name, serverURL: URL): Message {
    throw Exception("TCP request not implemented yet")
}

func TlsRequest(domain: Name, serverURL: URL): Message {
    throw Exception("TLS request not implemented yet")
}

func HttpsRequest(domain: Name, serverURL: URL): Message {
    throw Exception("HTTPS request not implemented yet")
}

func printServer(serverURL: URL): Unit {
    if (serverURL.scheme == "udp" || serverURL.scheme == "tcp") {
        println("DNS Server: ${serverURL.hostName}:${if (serverURL.port == "") { "53" } else { serverURL.port }}")
        return
    }
    println("DNS Server: ${serverURL}")
}

func printMessage(msg: Message): Unit {
    println("Header Section:")
    println("   Transaction ID: ${msg.header.id} ")
    println("   Flags: QR: ${msg.header.flags.response} Opcode: ${msg.header.flags.opCode} AA: ${msg.header.flags.authoritative} TC: ${msg.header.flags.truncated} RD: ${msg.header.flags.recursionDesired} RA: ${msg.header.flags.recursionAvailable} RCODE: ${msg.header.flags.rCode}")
    println("   Questions: ${msg.header.qdCount} Answer RRs: ${msg.header.anCount} Authority RRs: ${msg.header.nsCount} Additional RRs: ${msg.header.arCount}")
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

func exit(code: Int64, message: String): Nothing {
    println(message)
    exit(code)
}
