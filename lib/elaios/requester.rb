class Elaios::Requester
  attr_reader :logger

  def initialize(options={})
    @name = options[:name] || 'elaios_client'
    @logger = options[:logger] || Logger.new(STDOUT).tap { |l|
      l.progname = @name
      l.level = ENV['LOG_LEVEL'] || 'info'
    }
    @callbacks_enabled = options[:callbacks_enabled] || true
    @promises_enabled = options[:promises_enabled] || false
    @blocks = {}
    @deferreds = {}
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
    generate_block(block, data)
    generate_promise(data) # Return a promise.
  end

  # Called internally by `push`. Exposed for testing.
  def update
    results = @in.pop
    return unless results
    results.split("\n").each do |result|
      @logger.debug(%(result given: #{result}))
      data = JSON.load(result) rescue nil
      next unless data
      @logger.debug(%(payload parsed: #{data.inspect}))
      call_block(data)
      call_promise(data)
    end
  end

  def generate_block(block, data)
    return unless @callbacks_enabled
    id = data['id']
    return unless block
    @logger.debug(%(registered block for id #{id}: #{block.inspect}))
    return unless block
    @blocks[id] = block
  end

  def call_block(data)
    return unless @callbacks_enabled
    block = @blocks[data['id']]
    @logger.debug(%(block found: #{block.inspect}))
    return unless block
    self.instance_exec(data, &block)
    @logger.debug(%(block called: #{block.inspect}))
    @blocks.delete(data['id'])
    @logger.debug(%(block unregistered: #{block.inspect}))
  end

  def generate_promise(data)
    return unless @promises_enabled
    id = data['id']
    @logger.debug(%(generating a deferred and promise for id #{id}))
    @deferreds[id] = EM::Q.defer
    @deferreds[id].promise # Return the promise.
  end

  def call_promise(data)
    return unless @promises_enabled
    id = data['id']
    deferred = @deferreds[id]
    return unless deferred
    @logger.debug(%(deferred found: #{deferred.inspect}))
    deferred.resolve(data)
    @logger.debug(%(deferred resolved: #{deferred.inspect}))
    @deferred.delete(id)
    @logger.debug(%(deferred unregistered: #{deferred.inspect}))
  end
end
