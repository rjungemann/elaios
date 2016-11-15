# Elaios

Elaios is a transport-agnostic library for writing JSON-RPC clients and servers.
It can be used over TCP, HTTP, STOMP, and other transports, and can be used with
threaded-, evented-, or fiber-based code.

Furthermore, it is thread-safe, has a very simple API, and is well-tested.

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

### Basic requester (client) usage

```ruby
elaios_requester = Elaios::Requester.new

# Call a JSON-RPC method and don't expect a response.
elaios_requester.foo(['some', 'args'])

# Call a JSON-RPC method and expect a response.
elaios_requester.bar(['some', 'other', 'args']) do |data|
  # Do something with the response from the server...
end

request_1 = elaios_requester.pop
request_2 = elaios_requester.pop
# Send the requests to the server somehow (they will be JSON strings)...

# Get a response from the server somehow (it will be a JSON string). This will
# trigger the callback above to be called.
elaios_requester << response
```

### Basic responder (server) usage

```ruby
elaios_server = Elaios::Responder.new

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
# -----------------
# Elaios::Responder
# -----------------

# Create a new Elaios responder (server) object.
Elaios::Responder#new(options={})

`options` may consist of:

* `:name` - An optional name for a server.
* `:logger` - An optional logger object.

# Push an object onto the server for processing.
Elaios::Responder#push(obj)
Elaios::Responder#<<(obj)
Elaios::Responder#enq(obj)

# Pop a response off of the server.
Elaios::Responder#pop
Elaios::Responder#deq
Elaios::Responder#shift

# Push an object onto the server, update, and then pop a response off.
Elaios::Responder#process(obj)
Elaios::Responder#pushpop(obj)
Elaios::Responder#push_pop(obj)

# Register a handler.
Elaios::Responder#method_missing(name, &block)

# Generate a success response for sending to the client.
Elaios::Responder#res(method, id, data)
Elaios::Responder#response(method, id, data)

# Generate an error response for sending to the client.
Elaios::Responder#err(method, id, data)
Elaios::Responder#error(method, id, data)

# -----------------
# Elaios::Requester
# -----------------

# Create a new Elaios requester (client) object.
Elaios::Requester.new(options={})

`options` may consist of:

* `:name` - An optional name for a server.
* `:logger` - An optional logger object.

# Push an object onto the client for processing.
Elaios::Requester.push(obj)
Elaios::Requester.<<(obj)
Elaios::Requester.enq(obj)

# Pop a response off of the client.
Elaios::Requester#pop
Elaios::Requester#deq
Elaios::Requester#shift

# Call a JSON-RPC method.
Elaios::Requester#method_missing(name, args=nil, &block)
```

### Threaded TCP client usage

```ruby
# TCP client.
socket = TCPSocket.open('0.0.0.0', 5000)
elaios_requester = Elaios::Requester.new

# Incoming socket data.
Thread.new do
  loop do
    elaios_requester << socket.gets.chomp
  end
end

# Outgoing socket data.
Thread.new do
  loop do
    result = elaios_requester.pop
    socket.puts(result) if result
  end
end

# Make a service call and expect no response.
elaios_requester.ping('foo')

# Make a service call and expect a response.
elaios_requester.ping('foo') do |response|
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
    elaios_responder = Elaios::Responder.new

    # Create a server handler.
    elaios_responder.ping do |data|
      # Generate some sort of response. Note that we grab the method name and id
      # from the `data` hash.
      #
      # Also note within this block, `self` is the `elaios_responder` object.
      #
      res(data['method'], data['id'], { foo: 'bar' })
    end

    # Incoming socket data.
    Thread.new do
      loop do
        elaios_responder << socket.gets.chomp
      end
    end

    # Outgoing socket data.
    loop do
      result = elaios_responder.pop
      socket.puts(result) if result
      sleep(Float::MIN)
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

As shown in [Chapter 6 of the RabbitMQ tutorial](http://www.rabbitmq.com/tutorials/tutorial-six-python.html), you can use two queues to construct an RPC system.

**TODO:** Fill this in.

### AMQP usage

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

## Changelog

### 0.1.0

Initial commit.

### 0.1.1

Add more examples and bump Sinatra version for better compatibilty.

### 0.1.2

Added some STOMP specs.

### 0.1.3

Fix the description and add some more info to the README.

### 0.2.0

Rename `Elaios::Client` to `Elaios::Requester` and `Elaios::Server` to
`Elaios::Responder`. This is a non-breaking change (I kept aliases around so as
to not break any existing users of the library).

### 0.3.0

Added support for promises instead of, or in addition to, callbacks.

## TODO

* Consider alternative approaches to error responses.
* Finish filling in examples in the README.
* More strenuously test threading in specs.
* Finish filling in STOMP spec and examples.
* AMQP tests.
* AMQP examples.
* Consider promise.rb, allowing consumers to provide their own promise class.
  More info at https://github.com/lgierth/promise.rb
* Test default promise functionality.
* Document default promise functionality.
* Test overriding promise functionality.
* Document overriding promise functionality.
* Consider making sure threads and reactors are cleaned up when tests go bad.
* Come up with some fiber examples.

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/rjungemann/elaios.
