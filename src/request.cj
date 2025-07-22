package cnslookup

import std.net.*
import std.io.*
import std.convert.*
import stdx.encoding.url.*
import stdx.net.tls.*
import stdx.net.http.*
import dnsmsg.*

let TIMEOUT = Duration.second * 2

func DNSRequest(reqMsg: Message, serverURL: URL): Message {
    if (serverURL.scheme == "udp") {
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
}

func UdpRequest(reqMsg: Message, serverURL: URL): Message {
    let payload = reqMsg.toBytes()
    let port = UInt16.parse(serverURL.port)

    let respMsgBuf = Array<UInt8>(512, repeat: 0)
    // Create a UDP socket and send the request
    try (udpSocket = UdpSocket(bindAt: 0)) {
        udpSocket.sendTimeout = TIMEOUT
        udpSocket.receiveTimeout = TIMEOUT
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
    // Create a TCP socket and send the request
    try (tcpSocket = TcpSocket(serverURL.hostName, port)) {
        tcpSocket.connect(timeout: TIMEOUT)
        // Send the request
        let payloadLength = UInt16(payload.size)
        tcpSocket.write([UInt8(payloadLength >> 8), UInt8(payloadLength)])
        tcpSocket.write(payload)
        // Read the response
        tcpSocket.readTimeout = TIMEOUT
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
    // Create a TCP socket and upgrade to TLS
    try (tcpSocket = TcpSocket(serverURL.hostName, port)) {
        tcpSocket.connect(timeout: TIMEOUT)
        // Upgrade to TLS
        try (tlsSocket = TlsSocket.client(tcpSocket)) {
            // Perform the TLS handshake
            tlsSocket.handshake()
            // Send the request
            let payloadLength = UInt16(payload.size)
            tlsSocket.write([UInt8(payloadLength >> 8), UInt8(payloadLength)])
            tlsSocket.write(payload)
            // Read the response
            tlsSocket.readTimeout = TIMEOUT
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
    // Create a HTTP client with TLS configuration
    let client = ClientBuilder()
        .tlsConfig(TlsClientConfig())
        .writeTimeout(TIMEOUT)
        .readTimeout(TIMEOUT)
        .build()
    // Prepare the HTTP request
    let req = HttpRequestBuilder()
        .method("POST")
        .url(serverURL)
        .header("Content-Type", "application/dns-message")
        .header("Accept", "application/dns-message")
        .body(payload)
        .build()
    // Send the HTTP request
    let resp = client.send(req)
    // Check the response status
    if (resp.status != 200) {
        client.close()
        exit(1, "HTTPS request failed with status: ${resp.status}")
    }
    // Check if the response body size is valid
    if (resp.bodySize.isNone() || resp.bodySize == 0) {
        client.close()
        exit(1, "Failed to read response body size.")
    }
    // Read the response body into a buffer
    let respMsgBuf = Array<UInt8>(resp.bodySize.getOrThrow(), repeat: 0)
    resp.body.read(respMsgBuf)
    client.close()
    return Message.fromBytes(ByteBuffer(respMsgBuf))
}
