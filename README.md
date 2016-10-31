# Elaios

Elaios is a protocol-agnostic library for writing JSON-RPC clients and servers.
It can be used over TCP, HTTP, STOMP, and other protocols, and can be used with
threaded-, evented-, or fiber-based code.

Furthermore, it is thread-safe, has a very simple API, and well-tested.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'elaios'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install elaios

## Usage

Look in the `spec/integation` directory for more usage examples.

### Including Elaios in your code

From your Ruby code:

```ruby
require 'elaios'
```

### Basic client usage

```ruby
elaios_client = Elaios::Client.new

# Call a JSON-RPC method and don't expect a response.
elaios_client.foo(['some', 'args'])

# Call a JSON-RPC method and expect a response.
elaios_client.bar(['some', 'other', 'args']) do |data|
  # Do something with the response from the server...
end

request_1 = elaios_client.pop
request_2 = elaios_client.pop
# Send the requests to the server somehow (they will be JSON strings)...

# Get a response from the server somehow (it will be a JSON string). This will
# trigger the callback above to be called.
elaios_client << response
```

### Basic server usage

```ruby
elaios_server = Elaios::Server.new

elaios_server.foo do |data|
  # Do some processing here...
end

elaios_server.bar do |data|
  # To send a success response...
  res(data['method'], data['id'], ['some', 'response'])

  # Or, to send an error response...
  err(data['method'], data['id'], 'Sorry, an error occurred.')
end

# Get JSON string requests from the client somehow. These will trigger the above
# callbacks to be called.
elaios_server << request_1
elaios_server << request_2

response = elaios_server.pop
# Send the response to the client somehow (it will be a JSON string).
```

### API

```
# --------------
# Elaios::Server
# --------------

# Create a new Elaios server object.
Elaios::Server#new(options={})

`options` may consist of:

* `:name` - An optional name for a server.
* `:logger` - An optional logger object.

# Push an object onto the server for processing.
Elaios::Server#push(obj)
Elaios::Server#<<(obj)
Elaios::Server#enq(obj)

# Pop a response off of the server.
Elaios::Server#pop
Elaios::Server#deq
Elaios::Server#shift

# Push an object onto the server, update, and then pop a response off.
Elaios::Server#process(obj)
Elaios::Server#pushpop(obj)
Elaios::Server#push_pop(obj)

# Register a handler.
Elaios::Server#method_missing(name, &block)

# Generate a success response for sending to the client.
Elaios::Server#res(method, id, data)
Elaios::Server#response(method, id, data)

# Generate an error response for sending to the client.
Elaios::Server#err(method, id, data)
Elaios::Server#error(method, id, data)

# --------------
# Elaios::Client
# --------------

# Create a new Elaios client object.
Elaios::Client.new(options={})

`options` may consist of:

* `:name` - An optional name for a server.
* `:logger` - An optional logger object.

# Push an object onto the client for processing.
Elaios::Client.push(obj)
Elaios::Client.<<(obj)
Elaios::Client.enq(obj)

# Pop a response off of the client.
Elaios::Client#pop
Elaios::Client#deq
Elaios::Client#shift

# Call a JSON-RPC method.
Elaios::Client#method_missing(name, args=nil, &block)
```

### Threaded TCP client usage

```ruby
# TCP client.
socket = TCPSocket.open('0.0.0.0', 5000)
elaios_client = Elaios::Client.new

# Incoming socket data.
Thread.new do
  loop do
    elaios_client << socket.gets.chomp
  end
end

# Outgoing socket data.
Thread.new do
  loop do
    result = elaios_client.pop
    socket.puts(result) if result
  end
end

# Make a service call and expect no response.
elaios_client.ping('foo')

# Make a service call and expect a response.
elaios_client.ping('foo') do |response|
  # Do something with the response...
end
```

### Threaded TCP server usage

```ruby
# TCP server.
server = TCPServer.open(5000)
loop do
  # New incoming socket connection.
  Thread.fork(server.accept) do |socket|
    # We need a new Elaios instance for every incoming connection.
    elaios_server = Elaios::Server.new

    # Create a server handler.
    elaios_server.ping do |data|
      # Generate some sort of response. Note that we grab the method name and id
      # from the `data` hash.
      #
      # Also note that within this block, `self` is the `elaios_server` object.
      #
      res(data['method'], data['id'], { foo: 'bar' })
    end

    # Incoming socket data.
    Thread.new do
      loop do
        elaios_server << socket.gets.chomp
      end
    end

    # Outgoing socket data.
    Thread.new do
      loop do
        result = elaios_server.pop
        socket.puts(result) if result
      end
    end
  end
end
```

### Evented TCP client usage

**TODO:** Fill this in.

### Evented TCP server usage

**TODO:** Fill this in.

### HTTP client usage

**NOTE:** This is only one way to use Elaios with an HTTP client. You can use
any HTTP client library with Elaios.

**TODO:** Fill this in.

### HTTP server usage

**NOTE:** This is only one way to use Elaios with an HTTP server. You can use
any HTTP server library with Elaios.

**TODO:** Fill this in.

### STOMP usage

**TODO:** Fill this in.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run
`rake spec` to run the tests. You can also run `bin/console` for an interactive
prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To
release a new version, update the version number in `version.rb`, and then run
`bundle exec rake release`, which will create a git tag for the version, push
git commits and tags, and push the `.gem` file to
[rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/rjungemann/elaios.
