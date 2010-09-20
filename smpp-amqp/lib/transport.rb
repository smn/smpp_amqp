# require 'eventmachine'
# require 'amqp'
# require 'mq'
# require 'json'

class Smpp::Amqp::Transport < Smpp::Amqp
  
  def initialize(config)
    
    # set all logging to INFO
    log.level = Smpp::Base.logger.level = Logger::INFO
    
    @config = config
    @aconf = config['amqp']
    @sconf = config['smpp']
    
    connect_amqp @aconf do |amqp|
      connect_smpp @sconf do |smpp|
        
        # outbound SMSs from RabbitMQ queue
        outbound do |header, body|
          send_sms JSON.load(body), :via => smpp
        end
    
        # inbound SMSs from SMSC
        inbound do |sms|
          log.info "Received SMS, to #{sms.to}: #{sms.message}"
          publish sms, :routing_key => @aconf['inbound_key']
        end
    
        # handle delivery reports from SMSC
        delivered do |reference, stat|
          log.info "Received Delivery report"
          publish({:reference => reference, :stat => stat}, :routing_key => @aconf['delivery_report_key'])
        end
    
        # handle accepted SMS reports from SMSC
        accepted do |message_id, reference|
          log.info "SMS accepted for delivery #{message_id}, #{reference}"
          publish({:id => message_id, :reference => reference}, :routing_key => @aconf['accepted_key'])
        end
    
        # handle rejected SMS reports from SMSC
        rejected do |message_id, reference|
          log.info "Message rejected #{message_id}, #{reference}"
          publish({:id => message_id, :reference => reference}, :routing_key => @aconf['rejected_key'])
        end
      end
    end
  end
end
