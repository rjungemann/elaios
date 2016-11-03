class Elaios::Requester
  attr_reader :logger

  def initialize(options={})
    @name = options[:name] || 'elaios_client'
    @logger = options[:logger] || Logger.new(STDOUT).tap { |l|
      l.progname = @name
      l.level = ENV['LOG_LEVEL'] || 'info'
    }
    @blocks = {}
    @in = Simple::Queue.new
    @out = Simple::Queue.new
  end

  def push(obj)
    @in.push(obj)
    update
  end
  alias_method :<<, :push
  alias_method :enq, :push

  def pop
    @out.pop
  end
  alias_method :deq, :pop
  alias_method :shift, :pop

  # Call a remote JSON-RPC method. If a block is provided, then we expect a
  # response from the server.
  def method_missing(name, args=nil, &block)
    id = SecureRandom.uuid
    data = {
      'jsonrpc' => '2.0',
      'method' => name,
      'params' => args
    }
    # Only set the id if the client expects a response.
    data['id'] = id if block
    payload = JSON.dump(data)
    @logger.debug(%(method_missing payload: #{payload.inspect}))
    @out << payload
    return unless block
    @logger.debug(%(registered block for id #{id}: #{block.inspect}))
    @blocks[id] = block if block
  end

  # Called internally by `push`. Exposed for testing.
  def update
    results = @in.pop
    return unless results
    results.split("\n").each do |result|
      @logger.debug(%(result given: #{result}))
      payload = JSON.load(result) rescue nil
      next unless payload
      @logger.debug(%(payload parsed: #{payload.inspect}))
      block = @blocks[payload['id']]
      @logger.debug(%(block found: #{block.inspect}))
      next unless block
      self.instance_exec(payload, &block)
      @logger.debug(%(block called: #{block.inspect}))
      @blocks.delete(payload['id'])
      @logger.debug(%(block unregistered: #{block.inspect}))
    end
  end
end
