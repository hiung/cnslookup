package cnslookup

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
    let respMsg = DNSRequest(reqMsg, serverURL)
    // Print the response message
    printServer(serverURL)
    printMessage(respMsg)
    println(respMsg.header.id)
    println(respMsg.header.flags.response)
    println(respMsg.header.flags.opCode)
    println(respMsg.header.flags.recursionAvailable)
    println(respMsg.header.flags.rCode)
    println("========")
    println(reqMsg.toBytes())


    return 0
}