require 'singleton'
require 'drb/drb'
require 'drb/acl'
require 'rinda/ring'
require 'rinda/tuplespace'
require 'addressable/uri'
require 'active_support/i18n'
require 'active_support/inflector'
require 'socket'
module Distributed
  
  # Allows for the specific lookup of services on the ring server
      # 
      # Examples:
      #   Distribunaut::Utils::Rinda.register_or_renew(:app_name => :app_1, :space => :Test, :object => "Hello World!")
      #   Distribunaut::Utils::Rinda.register_or_renew(:app_name => :app_2, :space => :Test, :object => "Hello WORLD!")
      #   Distribunaut::Distributed.lookup("distributed://app_1/Test") # => "Hello World!"
      #   Distribunaut::Distributed.lookup("distributed://app_2/Test") # => "Hello WORLD!"
  def self.lookup(address)
    uri = Addressable::URI.parse(address)
    path = uri.path[1..uri.path.size] # remove the first slash
    host = uri.host
    Distributed::Utils::Rinda.read(:space => path.to_sym, :app_name => host.to_sym)
  end
  
  class Tuple
    
    attr_accessor :app_name
    attr_accessor :space
    attr_accessor :object
    attr_accessor :description
    attr_accessor :timeout
    
    def initialize(values = {})
      values.each do |k, v|
        self.send("#{k}=", v)
      end
    end
    
    def to_array
      [self.app_name, self.space, self.object, self.description]
    end
    
    def to_search_array
      [self.app_name, self.space, nil, nil]
    end
    
    def to_s
      self.to_array.inspect
    end
    
    class << self
      
      def from_array(ar)
        tuple = Distributed::Tuple.new
        tuple.app_name = ar[0]
        tuple.space = ar[1]
        tuple.object = ar[2]
        tuple.description = ar[3]

        tuple
      end
      
    end
      
  end # Tuple
  
  module Utils
    module Rinda

      class Config

        include Singleton

        attr_accessor :ring_server_host
        attr_accessor :ring_server_port
        attr_accessor :acl_list
        attr_accessor :acl_enabled

        def initialize
          @ring_server_host = '127.0.0.1'
          @ring_server_port = 9001
          @acl_list = ["deny", "all", "allow", "127.0.0.1", "allow", "localhost", "allow", Socket.gethostname]
          @acl_enabled = false
        end

      end
      class << self
        def generate_app_name(svc)
          "#{svc.class.name.gsub('::', '_')}_#{Socket.gethostname.gsub(/[^a-zA-Z0-9]/, '_')}_#{Process.pid}"
        end
        def ring_server(address_list=[])

          ring_config = Config.instance

          unless !ring_config.acl_enabled
            puts "ACL Enabled"
            unless ring_config.acl_list.empty?

              acl = ACL.new(ring_config.acl_list)
              puts "ACL:#{acl}"
              DRb.install_acl(acl)
              puts "ACL Installed !"
            end

          end

          ::DRb.start_service
          puts "start DRb client service!"

          if address_list.size > 0
            rs = ::Rinda::RingFinger.new(address_list).lookup_ring_any
          else 
            rs = ::Rinda::RingFinger.new([Config.instance.ring_server_host], Config.instance.ring_server_port).lookup_ring_any
            puts "Found Ringservers"
          end
          rs
        end

        def register_or_renew(values = {})
          tuple = build_tuple(values)
          begin
            ring_server.take(tuple.to_search_array, tuple.timeout)
          rescue ::Rinda::RequestExpiredError => e
            # it's ok that it expired. It could be that it was never registered.
          end
          register(values)
        end

        def remove_server(tuple)

          begin
            ring_server.take(tuple.to_search_array, tuple.timeout)
          rescue ::Rinda::RequestExpiredError => e

          end

          tuple

        end
        def register(values = {})
          tuple = build_tuple(values)
          ring_server.write(tuple.to_array, nil)
        end

        def get_observers_by_type(service_type, observer_events = ['write', 'take', 'delete'])
          
          observers =[]
          
          services = available_services_by_type(service_type)
          
          services.each do |service|
          
            puts service.app_name
            
            observer_events.each do |observer_event|
            
              observers << ring_server.notify(observer_event, [service.app_name, nil], nil)
          
            end
          
          end
          observers
          
        end
        def available_services_by_type(service_type)
          
          services = []
          available_services.each do |service|
            if service.app_name.to_s.match(/^#{service_type.to_s}_*/i)
              services << service
            end
          end
          services          
        end
        def available_services
          ring_server = self.ring_server
          all = ring_server.read_all([nil, nil, nil, nil])
          services = []
          all.each do |service|
            services << Distributed::Tuple.from_array(service)
          end
          services
        end
        
        def read(values = {})
          tuple = build_tuple(values)
          results = ring_server.read(tuple.to_array, tuple.timeout)
          tuple = Distributed::Tuple.from_array(results)
          tuple.object
        end
        
        def borrow(values = {}, &block)
          tuple = build_tuple(values)
          results = ring_server.take(tuple.to_array, tuple.timeout)
          tuple = Distributed::Tuple.from_array(results)
          tuple.space = "#{tuple.space}-onloan-#{Time.now}".to_sym
          register(tuple)
          begin
            yield tuple if block_given?
          rescue Exception => e
            raise e
          ensure
            # (.+)-onloan-.+$
            tuple.space.to_s.match(/(.+)-onloan-.+$/)
            tuple.space = $1.to_sym
            register(tuple)
          end
        end        
        def remove_all_services!
          available_services.each do |service|
            ring_server.take(service.to_array)
          end
        end
      
        private
          def build_tuple(values = {})
            return values if values.is_a?(Distributed::Tuple)
            Distributed::Tuple.new({:timeout => 10}.merge(values))
          end               
      end
    end #rinda
  end #utils
end #distrubuted