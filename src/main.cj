package cnslookup

import std.net.*
import std.io.*
import dnsmsg.*

main(args: Array<String>): Int64 {
    if (args.size < 2) {
        println("Usage: cnslookup <domain> <server>")
        return 1
    }
    let domain = args[0]
    let server = args[1]

    let reqMsg = MessageBuilder(id: ID()).addQuestion(Question(Name(domain), TypeAAAA, ClassIN)).build()
    let payload = reqMsg.toBytes()

    let bytes = Array<UInt8>(512, repeat: 0) 

    try (udpSocket = UdpSocket(bindAt: 8888)) {
        udpSocket.sendTimeout = Duration.second * 2
        udpSocket.receiveTimeout = Duration.second * 2
        udpSocket.bind()
        udpSocket.sendTo(IPSocketAddress(server, 53), payload)
        let (_, bytesRead) = udpSocket.receiveFrom(bytes)
    }
    let buffer = ByteBuffer(bytes)
    let respMsg = Message.fromBytes(buffer)

    println("Response ID: ${respMsg.header.id}")
    println("Is response: ${respMsg.header.flags.response}")
    for (question in respMsg.questions) {
        println("Question: ${question.name} ${question.qType} ${question.qClass}")
    }
    for (answer in respMsg.answers) {
        println("Answer: ${answer.name} ${answer.rType} ${answer.rClass} TTL: ${answer.ttl} Data: ${answer.rData}")
    }

    return 0
}
