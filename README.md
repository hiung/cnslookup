# cnslookup

A command-line DNS query tool based on [dnsmsg](https://github.com/hiung/dnsmsg), supporting UDP, TCP, TLS, and HTTPS protocols.

## Installation

1. Clone this repository:
   ```
   git clone https://github.com/hiung/cnslookup.git
   ```
2. Install dependencies and build:
   ```
   cjpm build
   ```

## Usage

```
cnslookup [OPTIONS] <domain> <dns-server-url>
```

### Arguments

- `<domain>`: The domain name to query
- `<dns-server-url>`: DNS server address, supports `udp://`, `tcp://`, `tls://`, and `https://` schemes

### Options

- `-t, --type TYPE`: Specify DNS query type (default: A)
- `-h, --help`: Show help information

### Examples

```
cnslookup example.com udp://8.8.8.8:53
cnslookup example.com tcp://1.1.1.1:53 --type=AAAA
cnslookup example.com tls://1.1.1.1:853
cnslookup example.com https://dns.google/dns-query
```

## Dependency

- [dnsmsg](https://github.com/hiung/dnsmsg)

## License