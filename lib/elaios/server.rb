class Elaios::Server
  attr_reader :logger

  def initialize(options={})
    @name = options[:name] || 'elaios_server'
    @logger = options[:logger] || Logger.new(STDOUT).tap { |l|
      l.progname = @name
      l.level = ENV['LOG_LEVEL'] || 'info'
    }
    @blocks = {}
    @in = Simple::Queue.new
    @out = Simple::Queue.new
    @mutex = Mutex.new
  end

  def push(obj)
    @mutex.synchronize { unsafe_push(obj) }
  end
  alias_method :<<, :push
  alias_method :enq, :push

  def pop
    @mutex.synchronize { unsafe_pop }
  end
  alias_method :deq, :pop
  alias_method :shift, :pop

  def process(obj)
    @mutex.synchronize { unsafe_push(obj); unsafe_pop }
  end
  alias_method :pushpop, :process
  alias_method :push_pop, :process

  # Set up a handler.
  def method_missing(name, &block)
    @blocks[name] = block
    @logger.debug(%(registered handler for #{name}: #{block.inspect}))
  end

  # Send a success response to the client.
  def res(method, id, data)
    payload = JSON.dump({
      'jsonrpc' => '2.0',
      'method' => method,
      'result' => data,
      'id' => id
    })
    @logger.debug(%(enqueueing success payload for sending: #{payload.inspect}))
    @out << payload
  end
  alias_method :response, :res

  # Send an error response to the client.
  def err(method, id, data)
    payload = JSON.dump({
      'jsonrpc' => '2.0',
      'method' => method,
      'error' => data,
      'id' => id
    })
    @logger.debug(%(enqueueing error payload for sending: #{payload.inspect}))
    @out << payload
  end
  alias_method :error, :err

  # Called internally by `push`. Exposed for testing.
  def update
    results = @in.pop
    return unless results
    results.split("\n").each do |result|
      @logger.debug(%(result given: #{result}))
      payload = JSON.load(result) rescue nil
      next unless payload
      @logger.debug(%(payload parsed: #{payload.inspect}))
      block = @blocks[payload['method'].to_sym]
      @logger.debug(%(block found: #{block.inspect}))
      next unless block
      self.instance_exec(payload, &block)
      @logger.debug(%(block called: #{block.inspect}))
    end
  end

  # Called internally by `push` and `process`. Exposed for testing.
  def unsafe_push(obj)
    @in.push(obj)
    update
  end

  # Called internally by `pop` and `process`. Exposed for testing.
  def unsafe_pop
    @out.pop
  end
end
