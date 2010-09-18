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
    @logger ||= Logger.new(STDOUT)
    @logger.level = Logger::DEBUG
    @logger
  end
  
  def connect_amqp
    log.info "Connecting to RabbitMQ"
    AMQP.start(:user => @aconf['username'], :pass => @aconf['password'],
                  :host => @aconf['host'], :port => @aconf['port'], 
                  :vhost => @aconf['vhost']) do |connection|
        
        exchange = 'exchange'
        log.info("Publishing to exchange: #{exchange}")
        
        @publisher = MQ.new(connection)
        @publisher.topic(exchange)
        
        start_consumer connection
    end
  end
  
  def start_consumer(connection)
    queue = "smpp.outbound"
    exchange = "exchange"
    key = "outbound.key"
    
    log.info("Starting consumer on queue: #{queue} bound to " +
              "exchange: #{exchange} with key: #{key}")
    
    # prefetch only one for evented systems, otherwise during
    # restarts messages could be lost.
    channel = MQ.new(connection)
    channel.prefetch(1)
    
    queue = channel.queue(queue)
    queue.bind(MQ.topic(exchange), :key => key).subscribe do |header, body|
      send_sms body
    end
  end
  
  def send_sms sms
    log.info "I should send #{sms}"
  end
  
  def connect_smpp
    log.info "Starting SMPP"
  end
  
end