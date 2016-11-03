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

  it 'works in an evented manner when used with a STOMP service' do
    module StompRequester
      include EM::Protocols::Stomp

      def initialize(options)
        @options = options
      end

      def connection_completed
        connect(@options.auth)
      end

      def receive_msg(msg)
        if msg.command == 'CONNECTED'
          subscribe(@options.response_queue)
          EM::add_periodic_timer(Float::MIN) do
            result = @options.elaios_requester.pop
            send(@options.request_queue, result) if result
          end
        else
          @options.elaios_requester << msg.body
        end
      end
    end

    module StompResponder
      include EM::Protocols::Stomp

      def initialize(options)
        @options = options
      end

      def connection_completed
        connect(@options.auth)
      end

      def receive_msg(msg)
        if msg.command == 'CONNECTED'
          subscribe(@options.request_queue)
          EM::add_periodic_timer(Float::MIN) do
            result = @options.elaios_responder.pop
            send(@options.response_queue, result) if result
          end
        else
          @options.elaios_responder << msg.body
        end
      end
    end

    requests = []
    responses = []
    EM.run do
      start_stomp_server!(@port)

      elaios_responder = Elaios::Responder.new
      elaios_responder.ping do |data|
        requests << data
        res(data['method'], data['id'], { foo: 'bar' })
      end
      elaios_requester = Elaios::Requester.new
      options = OpenStruct.new({
        auth: {
          login: 'guest',
          passcode: 'guest'
        },
        request_queue: '/queue/test',
        response_queue: '/queue/test-response',
        elaios_responder: elaios_responder,
        elaios_requester: elaios_requester
      })
      EM.connect('localhost', @port, StompRequester, options)
      EM.connect('localhost', @port, StompResponder, options)

      EM.next_tick do
        elaios_requester.ping('foo')
        elaios_requester.ping('foo') do |data|
          responses << data
          EM.stop_event_loop
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
