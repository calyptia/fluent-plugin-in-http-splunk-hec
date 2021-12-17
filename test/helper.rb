$LOAD_PATH.unshift(File.expand_path("../../", __FILE__))
require "test-unit"
require "fluent/test"
require "fluent/test/driver/input"
require "fluent/test/driver/filter"
require "fluent/test/helpers"

Test::Unit::TestCase.include(Fluent::Test::Helpers)
Test::Unit::TestCase.extend(Fluent::Test::Helpers)

# Just copy and pasted from:
# https://github.com/fluent/fluentd/blob/5281e2be0d4d4802a14fa5d33a779ebe995214f6/test/helper.rb#L74-L123
def unused_port(num = 1, protocol: :tcp, bind: "0.0.0.0")
  case protocol
  when :tcp
    unused_port_tcp(num)
  when :udp
    unused_port_udp(num, bind: bind)
  else
    raise ArgumentError, "unknown protocol: #{protocol}"
  end
end

def unused_port_tcp(num = 1)
  ports = []
  sockets = []
  num.times do
    s = TCPServer.open(0)
    sockets << s
    ports << s.addr[1]
  end
  sockets.each{|s| s.close }
  if num == 1
    return ports.first
  else
    return *ports
  end
end

PORT_RANGE_AVAILABLE = (1024...65535)

def unused_port_udp(num = 1, bind: "0.0.0.0")
  family = IPAddr.new(IPSocket.getaddress(bind)).ipv4? ? ::Socket::AF_INET : ::Socket::AF_INET6
  ports = []
  sockets = []
  while ports.size < num
    port = rand(PORT_RANGE_AVAILABLE)
    u = UDPSocket.new(family)
    if (u.bind(bind, port) rescue nil)
      ports << port
      sockets << u
    else
      u.close
    end
  end
  sockets.each{|s| s.close }
  if num == 1
    return ports.first
  else
    return *ports
  end
end
