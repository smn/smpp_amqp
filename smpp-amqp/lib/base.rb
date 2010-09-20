require 'eventmachine'
require 'amqp'
require 'mq'
require 'json'

class Smpp::Amqp
  
  attr_accessor :inbound_responders, :accepted_responders, 
                :delivered_responders, :rejected_responders
  
  class Error < Exception
  end
  
  def log
    @logger ||= Logger.new(STDOUT)
    @logger
  end
  
  def connect_amqp(config)
    connection = AMQP.connect(:user => config['username'],
                              :pass => config['password'],
                              :host => config['host'], 
                              :port => config['port'], 
                              :vhost => config['vhost'])
    yield connection if block_given?
  end
  
  def publish data, options = {}
    exchange.publish data.to_json, options
  end
  
  def exchange
    @exchange ||= MQ.topic(@aconf['exchange'])
  end
  
  def outbound &block
    @outbound ||= queue(exchange, @aconf['outbound_queue'], @aconf['outbound_key'])
    @outbound.subscribe &block
  end
  
  def queue(exchange, name, routing_key)
    MQ.queue(name).bind(exchange, :key=> routing_key)
  end
  
  def inbound &block
    inbound_responders << block
  end
  
  def inbound_responders
    @inbound_responders ||= []
  end
  
  def delivered &block
    delivered_responders << block
  end
  
  def delivered_responders
    @delivered_responders ||= []
  end
  
  def accepted &block
    accepted_responders << block
  end
  
  def accepted_responders
    @accepted_responders ||= []
  end
  
  def rejected &block
    rejected_responders << block
  end
  
  def rejected_responders
    @rejected_responders ||= []
  end
  
  def send_sms sms, options = {}
    log.info "Sending out SMS: #{sms}"
    transceiver = options[:via] || @transceiver
    raise ::Error, "Unable to send out SMS" if transceiver.nil?
    transceiver.send_mt(sms["message_id"], sms["from"], sms["to"], sms["message"])
  rescue InvalidStateException => e
    log.error e
  end
  
  def connect_smpp(config)
    # FIXME: this is fairly ugly
    log.info "Connecting SMPP Transceiver to #{config["host"]}:#{config["port"]}"
    @transceiver = EventMachine::connect(
      config["host"], 
      config["port"], 
      Smpp::Transceiver, 
      {
        :host => config["host"],
        :port => config["port"],
        :system_id => config["username"],
        :password => config["password"],
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
    yield @transceiver if block_given?
  end
  
  def mo_received(transceiver, pdu)
    sms = Sms.from_pdu pdu
    inbound_responders.each { |responder| responder.call(sms) }
  end

  def delivery_report_received(transceiver, pdu)
    delivered_responders.each { |responder| responder.call(pdu.msg_reference, pdu.stat) }
  end

  def message_accepted(transceiver, mt_message_id, pdu)
    accepted_responders.each { |responder| responder.call(mt_message_id, pdu.message_id) }
  end

  def message_rejected(transceiver, mt_message_id, pdu)
    rejected_responders.each { |responder| responder.call(mt_message_id, pdu.message_id) }
  end

  def bound(transceiver)
    log.info "Delegate: transceiver bound"
  end

  def unbound(transceiver)  
    log.info "Delegate: transceiver unbound"
    EventMachine::stop_event_loop
  end
end

class Sms
  attr_accessor :id, :from, :to, :message
  
  def initialize(options)
    @id = options[:id]
    @to = options[:to]
    @from = options[:from]
    @message = options[:message]
    @options = options
  end
  
  def to_json
    @options.to_json
  end
  
  def self.from_pdu pdu
    warn "Setting SMS.id from pdu.msg_reference, unsure if that's correct."
    new(:id => pdu.msg_reference, :to => pdu.destination_addr, 
        :from => pdu.source_addr, :message => pdu.short_message)
  end
end
