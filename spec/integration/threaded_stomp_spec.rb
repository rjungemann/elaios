require 'spec_helper'

describe Elaios, integration: true do
  before(:each) do
    @port = random_port
  end

  around(:each) do |example|
    Timeout::timeout(10) do
      example.run
    end
  end

  it 'works in an threaded manner when used with a STOMP service' do
    done = false
    requests = []
    responses = []

    # Running Eventmachine in a separate thread because the reactor blocks.
    Thread.new do
      EM.run do
        start_stomp_server!(@port)
      end
    end

    loop do
      begin
        s = TCPSocket.new('localhost', @port)
        s.close
        break
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
        # Do nothing...
      end
      sleep(Float::MIN)
    end

    auth_login = 'guest'
    auth_passcode = 'guest'
    request_queue = '/queue/test'
    response_queue = '/queue/test-response'

    elaios_client = Elaios::Client.new
    requester_client = Stomp::Client.new(auth_login, auth_passcode, 'localhost', @port)

    # Incoming socket data.
    requester_client.subscribe(response_queue) do |msg|
      elaios_client << msg.body
    end

    # Outgoing socket data.
    Thread.new do
      loop do
        break if done
        result = elaios_client.pop
        requester_client.publish(request_queue, result) if result
      end
    end

    elaios_server = Elaios::Server.new
    responder_client = Stomp::Client.new(auth_login, auth_passcode, 'localhost', @port)

    # Create a server handler.
    elaios_server.ping do |data|
      requests << data
      res(data['method'], data['id'], { foo: 'bar' })
    end

    # Incoming socket data.
    responder_client.subscribe(request_queue) do |msg|
      elaios_server << msg.body
    end

    # Outgoing socket data.
    Thread.new do
      loop do
        break if done
        result = elaios_server.pop
        responder_client.publish(response_queue, result) if result
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

    # Gracefully shut everything down.
    requester_client.close
    responder_client.close

    # Stop the reactor.
    EM.stop_event_loop

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
