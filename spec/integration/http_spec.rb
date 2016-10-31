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

  it 'works when used with an HTTP server' do
    class App < Sinatra::Base
      head '/rpc' do
        'OK'
      end

      post '/rpc' do
        elaios_server = request.env['rack.elaios_server']
        result = elaios_server.process(request.body.read)
        (result || '')
      end
    end

    done = false
    requests = []
    responses = []

    # HTTP Server.
    elaios_server = Elaios::Server.new
    http_server = WEBrick::HTTPServer.new({
      Port: @port,
      Logger: Logger.new(StringIO.new),
      AccessLog: Logger.new(StringIO.new),
    })
    http_server.mount('/', Rack::Handler::WEBrick, Rack::Builder.new do
      # Inject the `elaios_server` into the server.
      use Rack::Config do |env|
        env['rack.elaios_server'] = elaios_server
      end
      # Run the Sinatra test app.
      run App.new
    end)
    Thread.new do
      http_server.start
    end
    # Create a server handler.
    elaios_server.ping do |data|
      requests << data
      res(data['method'], data['id'], { foo: 'bar' })
    end

    # Wait for HTTP server to start (keep making HEAD requests until success).
    begin
      Net::HTTP.start('localhost', @port) { |http| http.head('/rpc') }
    rescue Errno::ECONNREFUSED => e
      retry
    end

    # Tell the HTTP server to stay up until done.
    Thread.new do
      loop do
        http_server.stop and raise StopIteration if done
        sleep(Float::MIN)
      end
    end

    # HTTP client.
    elaios_client = Elaios::Client.new

    # Every time the `elaios_client` receives a message, make an HTTP request
    # and send it to the server.
    #
    Thread.new do
      loop do
        raise StopIteration if done
        result = elaios_client.pop
        next unless result
        uri = URI("http://localhost:#{@port}/rpc")
        req = Net::HTTP::Post.new(uri.path)
        req['Content-Type'] = 'application/json'
        req.body = result
        Net::HTTP.start(uri.hostname, uri.port) do |http|
          http.request(req) do |res|
            result = res.body
            elaios_client << result if result
          end
        end
      end
    end

    # Make client requests.
    elaios_client.ping('foo')
    elaios_client.ping('foo') do |response|
      responses << response
      done = true
    end

    # Wait for everything to finish.
    sleep(Float::MIN) until done

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
