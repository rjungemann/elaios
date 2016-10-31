require 'spec_helper'

describe Elaios, integration: true do
  before(:each) do
    @port = random_port
  end

  around(:each) do |example|
    Timeout::timeout(5) do
      example.run
    end
  end

  it 'works when used with a threaded server' do
    done = false
    requests = []
    responses = []

    # TCP server.
    server = TCPServer.open(@port)
    Thread.new do
      loop do
        raise StopIteration if done

        # New incoming socket connection.
        Thread.fork(server.accept) do |socket|
          # We need a new Elaios instance for every incoming connection.
          elaios_server = Elaios::Server.new

          # Create a server handler.
          elaios_server.ping do |data|
            requests << data
            res(data['method'], data['id'], { foo: 'bar' })
          end

          # Incoming socket data.
          Thread.new do
            loop do
              raise StopIteration if done
              result = socket.gets.chomp
              elaios_server << result
            end
          end

          # Outgoing socket data.
          Thread.new do
            loop do
              raise StopIteration if done
              result = elaios_server.pop
              socket.puts(result) if result
            end
          end
        end
      end
    end

    # TCP client.
    socket = TCPSocket.open('127.0.0.1', @port)
    elaios_client = Elaios::Client.new

    # Incoming socket data.
    Thread.new do
      loop do
        raise StopIteration if done
        result = socket.gets.chomp
        elaios_client << result
      end
    end

    # Outgoing socket data.
    Thread.new do
      loop do
        raise StopIteration if done
        result = elaios_client.pop
        socket.puts(result) if result
      end
    end

    # Try making some service calls.
    elaios_client.ping('foo')
    elaios_client.ping('foo') do |response|
      responses << response
      done = true
    end

    # Wait for everything to finish.
    sleep Float::MIN until done

    # Inspect the requests the server received.
    expect(requests.length).to eq(2)
    request_1 = requests.first
    expect(request_1['id']).to be_nil
    expect(request_1['method']).to eq('ping')
    expect(request_1['params']).to eq('foo')
    request_2 = requests.last
    expect(request_2['id']).to_not be_nil
    expect(request_2['method']).to eq('ping')
    expect(request_2['params']).to eq('foo')

    # Inspect the responses the client received.
    expect(responses.length).to eq(1)
    response = responses.last
    expect(response['id']).to_not be_nil
    expect(response['method']).to eq('ping')
    expect(response['result']).to eq({ 'foo' => 'bar' })
  end
end
