require 'eventmachine'
require 'amqp'

class Smpp::Amqp
  
  def initialize(config)
    @config = config
    @aconf = config['amqp']
    @sconf = config['smpp']
    
    connect_amqp
    connect_smpp
  end
  
  def connect_amqp
    puts "connecting to rabbit"
    credentials = {
      :user => @aconf['username'], 
      :pass => @aconf['password'],
      :host => @aconf['host'], 
      :port => @aconf['port'], 
      :vhost => @aconf['vhost']
    }
    puts credentials
    AMQP.connect(credentials) do |conn|
      @connection = conn
      channel = MQ.new(@connection)
      @xchange = channel.fanout(@aconf['exchange'], :durable => true)
    end
  end
  
  def connect_smpp
  end
  
end