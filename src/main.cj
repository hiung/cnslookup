package cnslookup

import std.net.*
import std.io.*
import std.regex.*
import std.convert.*
import std.env.*
import stdx.encoding.url.*
import stdx.net.tls.*
import stdx.net.http.*
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
    let reqMsg = MessageBuilder(id: ID()).addQuestion(Question(domain, TypeA, ClassIN)).build()
    let respMsg = if (serverURL.scheme == "udp") {
        UdpRequest(reqMsg, serverURL)
    } else if (serverURL.scheme == "tcp") {
        TcpRequest(reqMsg, serverURL)
    } else if (serverURL.scheme == "tls") {
        TlsRequest(reqMsg, serverURL)
    } else if (serverURL.scheme == "https") {
        HttpsRequest(reqMsg, serverURL)
    } else {
        exit(1, "Unsupported scheme: ${serverURL.scheme}. Use udp://, tcp://, tls://, or https://")
    }
    // Print the response message
    printServer(serverURL)
    printMessage(respMsg)

    return 0
}

func UdpRequest(reqMsg: Message, serverURL: URL): Message {
    let payload = reqMsg.toBytes()
    let port = UInt16.parse(serverURL.port)

    let respMsgBuf = Array<UInt8>(512, repeat: 0)

    try (udpSocket = UdpSocket(bindAt: 0)) {
        udpSocket.sendTimeout = Duration.second * 2
        udpSocket.receiveTimeout = Duration.second * 2
        udpSocket.bind()
        udpSocket.sendTo(IPSocketAddress(serverURL.hostName, port), payload)
        udpSocket.receiveFrom(respMsgBuf)
    }
    // Convert the response buffer to a Message object
    return Message.fromBytes(ByteBuffer(respMsgBuf))
}

func TcpRequest(reqMsg: Message, serverURL: URL): Message {
    let payload = reqMsg.toBytes()
    let port = UInt16.parse(serverURL.port)

    var respMsgBuf = Array<UInt8>()

    try (tcpSocket = TcpSocket(serverURL.hostName, port)) {
        tcpSocket.connect(timeout: Duration.second * 2)
        // Send the request
        let payloadLength = UInt16(payload.size)
        tcpSocket.write([UInt8(payloadLength >> 8), UInt8(payloadLength)])
        tcpSocket.write(payload)
        // Read the response
        tcpSocket.readTimeout = Duration.second * 2
        let readLengthBuf = Array<UInt8>(2, repeat: 0)
        tcpSocket.read(readLengthBuf)
        let readLength = (UInt16(readLengthBuf[0]) << 8) | UInt16(readLengthBuf[1])
        respMsgBuf = Array<UInt8>(Int64(readLength), repeat: 0)
        tcpSocket.read(respMsgBuf)
    }
    // Convert the response buffer to a Message object
    return Message.fromBytes(ByteBuffer(respMsgBuf))
}

func TlsRequest(reqMsg: Message, serverURL: URL): Message {
    let payload = reqMsg.toBytes()
    let port = UInt16.parse(serverURL.port)

    var respMsgBuf = Array<UInt8>()

    try (tcpSocket = TcpSocket(serverURL.hostName, port)) {
        tcpSocket.connect(timeout: Duration.second * 2)
        // Upgrade to TLS
        try (tlsSocket = TlsSocket.client(tcpSocket)) {
            // Perform the TLS handshake
            tlsSocket.handshake()
            // Send the request
            let payloadLength = UInt16(payload.size)
            tlsSocket.write([UInt8(payloadLength >> 8), UInt8(payloadLength)])
            tlsSocket.write(payload)
            // Read the response
            tlsSocket.readTimeout = Duration.second * 2
            let readLengthBuf = Array<UInt8>(2, repeat: 0)
            tlsSocket.read(readLengthBuf)
            let readLength = (UInt16(readLengthBuf[0]) << 8) | UInt16(readLengthBuf[1])
            respMsgBuf = Array<UInt8>(Int64(readLength), repeat: 0)
            tlsSocket.read(respMsgBuf)
        }
    }
    // Convert the response buffer to a Message object
    return Message.fromBytes(ByteBuffer(respMsgBuf))
}

func HttpsRequest(reqMsg: Message, serverURL: URL): Message {
    let payload = reqMsg.toBytes()
    let client = ClientBuilder()
        .tlsConfig(TlsClientConfig())
        .writeTimeout(Duration.second * 2)
        .readTimeout(Duration.second * 2)
        .build()
    let req = HttpRequestBuilder()
        .method("POST")
        .url(serverURL)
        .header("Content-Type", "application/dns-message")
        .header("Accept", "application/dns-message")
        .body(payload)
        .build()
    let resp = client.send(req)
    if (resp.status != 200) {
        exit(1, "HTTPS request failed with status: ${resp.status}")
    }
    client.close()
    // Send the request and get the response
    let respMsgBuf = Array<UInt8>(resp.bodySize ?? 0, repeat: 0)
    resp.body.read(respMsgBuf)
    return Message.fromBytes(ByteBuffer(respMsgBuf))
    throw Exception()
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

func exit(code: Int64, message: String): Nothing {
    println(message)
    exit(code)
}
