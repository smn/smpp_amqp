require 'eventmachine'
require 'amqp'
require 'mq'
require 'json'

class Smpp::Amqp
  
  def initialize(config)
    @config = config
    @aconf = config['amqp']
    @sconf = config['smpp']
    
    connect_amqp
    connect_smpp
  end
  
  def log
    @logger ||= Logger.new(STDOUT)
    Smpp::Base.logger = @logger
    @logger.level = Logger::DEBUG
    @logger
  end
  
  def connect_amqp
    log.info "Connecting to RabbitMQ"
    connection = AMQP.connect(:user => @aconf['username'], :pass => @aconf['password'],
                  :host => @aconf['host'], :port => @aconf['port'], 
                  :vhost => @aconf['vhost'])
    
    exchange = 'richmond'
    log.info("Publishing to exchange: #{exchange}")
    
    @inbound = MQ.topic(exchange, :key => 'inbound.key')
    @delivery_report = MQ.topic(exchange, :key => 'outbound.delivery_report')
    @accepted = MQ.topic(exchange, :key => 'outbound.accepted')
    
    start_consumer connection
  end
  
  def start_consumer(connection)
    queue = "smpp.outbound"
    exchange = "richmond"
    key = "outbound.key"
    
    log.info("Starting consumer on queue: #{queue} bound to " +
              "exchange: #{exchange} with key: #{key}")
    
    # prefetch only one for evented systems, otherwise during
    # restarts messages could be lost.
    channel = MQ.new(connection)
    channel.prefetch(1)
    
    queue = channel.queue(queue)
    queue.bind(MQ.topic(exchange), :key => key).subscribe do |header, body|
      log.info "Received body #{body}"
      send_sms JSON.load(body)
    end
  end
  
  def send_sms sms
    log.info "I should send #{sms}"
    unless @transceiver.nil?
      @transceiver.send_mt(sms["message_id"], sms["from"], sms["to"], sms["message"])
    end
  end
  
  def connect_smpp
    log.info "Connecting SMPP Transceiver to #{@sconf["host"]}:#{@sconf["port"]}"
    @transceiver = EventMachine::connect(
      @sconf["host"], 
      @sconf["port"], 
      Smpp::Transceiver, 
      {
        :host => @sconf["host"],
        :port => @sconf["port"],
        :system_id => @sconf["username"],
        :password => @sconf["password"],
        :system_type => '', # default given according to SMPP 3.4 Spec
        :interface_version => 52,
        :source_ton  => 0,
        :source_npi => 1,
        :destination_ton => 1,
        :destination_npi => 1,
        :source_address_range => '',
        :destination_address_range => '',
        :enquire_link_delay_secs => 10
      }, 
      self    # delegate that will receive callbacks on MOs and DRs and other events
    )
  end
  
  def mo_received(transceiver, pdu)
    sender = pdu.source_addr
    recipient = pdu.destination_addr
    message = pdu.short_message
    log.info "Received SMS from #{sender} to #{recipient}: #{message}"
    @inbound.publish({ :from => sender, :to => recipient, :text => message }.to_json)
  end

  def delivery_report_received(transceiver, pdu)
    log.info "Delegate: delivery_report_received: ref #{pdu.msg_reference} stat #{pdu.stat}"
    @delivery_report.publish({ :reference => pdu.msg_reference, :stat => pdu.stat }.to_json)
  end

  def message_accepted(transceiver, mt_message_id, pdu)
    log.info "Delegate: message_accepted: id #{mt_message_id} smsc ref id: #{pdu.message_id}"
    @accepted.publish({:id => mt_message_id, :reference => pdu.message_id }.to_json)
    
  end

  def message_rejected(transceiver, mt_message_id, pdu)
    log.info "Delegate: message_rejected: id #{mt_message_id} smsc ref id: #{pdu.message_id}"
    @rejected.publish({:id => mt_message_id, :reference => pdu.message_id}.to_json)
  end

  def bound(transceiver)
    log.info "Delegate: transceiver bound"
  end

  def unbound(transceiver)  
    log.info "Delegate: transceiver unbound"
    EventMachine::stop_event_loop
  end
  
  
end