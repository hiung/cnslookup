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

    let reqMsg = MessageBuilder(id: ID()).addQuestion(Question(Name(domain), TypeA, ClassIN)).build()
    let payload = reqMsg.toBytes()

    let bytes = Array<UInt8>(512, repeat: 0) 

    try (udpSocket = UdpSocket(bindAt: 0)) {
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
        println("Question: ${question.name} ${getTypeName(question.qType)} ${getClassName(question.qClass)}")
    }
    for (answer in respMsg.answers) {
        println("Answer: ${answer.name} ${getTypeName(answer.rType)} ${getClassName(answer.rClass)} ${answer.ttl} ${answer.rData}")
    }

    return 0
}
