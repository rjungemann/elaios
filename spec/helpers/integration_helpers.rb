module IntegrationHelpers
  def random_port
    socket = Socket.new(:INET, :STREAM, 0)
    socket.bind(Addrinfo.tcp('127.0.0.1', 0))
    port = socket.local_address.ip_port
    socket.close
    port
  end

  # Start a fake STOMP server. In reality you'll use RabbitMQ or similar.
  def start_stomp_server!(port)
    # Just some stubbing to get the stomp server to work in rspec.
    allow_any_instance_of(StompServer::Configurator).to receive(:getopts) {
      {
        log_level: 'ERROR',
        working_dir: '.',
        logdir: 'log',
        etcdir: 'etc',
        auth: false,
        session_cache: 0,
        pidfile: 'etc/stomp.pid'
      }
    }
    # Create a config object. We stub logger to quiesce annoying log messages.
    allow_any_instance_of(Logger).to receive(:debug) {}
    config = StompServer::Configurator.new
    allow_any_instance_of(Logger).to receive(:debug).and_call_original
    # Set up the stomp server and prepare it to receive messages.
    stomp = StompServer::Run.new(config.opts).tap { |s| s.start }
    # Start the stomp server.
    EM.start_server(
      'localhost',
      port,
      StompServer::Protocols::Stomp,
      stomp.auth_required,
      stomp.queue_manager,
      stomp.topic_manager,
      stomp.stompauth,
      config.opts
    )
  end
end
