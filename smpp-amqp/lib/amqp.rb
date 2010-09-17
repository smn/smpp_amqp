require 'eventmachine'
require 'amqp'
require 'mq'

class Smpp::Amqp
  
  attr_accessor :publisher
  
  def initialize(config)
    @config = config
    @aconf = config['amqp']
    @sconf = config['smpp']
    
    connect_amqp
    connect_smpp
  end
  
  def log
    # keep a backlog of 10 log files, maximum of 10 MB in size each
    @logger ||= Logger.new('transport.log', 10, 10485760)
    @logger.level = Logger::DEBUG
    @logger
  end
  
  def connect_amqp
    log.info "Connecting to RabbitMQ"
    AMQP.start(:user => @aconf['username'], :pass => @aconf['password'],
                  :host => @aconf['host'], :port => @aconf['port'], 
                  :vhost => @aconf['vhost']) do |connection|
        @publisher = MQ.new(connection)
        @publisher.topic('smpp.inbound')
        
        start_consumer connection
    end
  end
  
  def start_consumer(connection)
    log.info("Starting consumer #{connection}")
  end
  
  def connect_smpp
    log.info "Starting SMPP"
  end
  
end