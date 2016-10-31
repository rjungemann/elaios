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

  it 'works when used with an evented server' do
    class ServerSocket < EM::Connection
      def initialize(options)
        @options = options
        @options['server_socket'] = self
      end

      def receive_data(data)
        @options.elaios_server << data
      end
    end

    class ClientSocket < EM::Connection
      def initialize(options)
        @options = options
        @options['client_socket'] = self
      end

      def receive_data(data)
        @options.elaios_client << data
      end
    end

    requests = []
    responses = []
    EM.run do
      # This struct will be used to pass data into the handler classes.
      options = OpenStruct.new({})

      # Start the server.
      options.elaios_server = Elaios::Server.new
      EM::start_server('127.0.0.1', @port, ServerSocket, options)
      options.elaios_server.ping do |data|
        requests << data
        res(data['method'], data['id'], { foo: 'bar' })
      end
      EM::add_periodic_timer(Float::MIN) do
        result = options.elaios_server.pop
        options.server_socket.send_data(result + "\n") if result
      end

      # Start the client.
      options.elaios_client = Elaios::Client.new
      EM::connect('127.0.0.1', @port, ClientSocket, options)
      EM::add_periodic_timer(Float::MIN) do
        result = options.elaios_client.pop
        options.client_socket.send_data(result + "\n") if result
      end

      # Send some messages to the server.
      EM::next_tick do
        options.elaios_client.ping('foo')
        options.elaios_client.ping('foo') do |response|
          responses << response
          EM::stop_event_loop
        end
      end
    end

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
