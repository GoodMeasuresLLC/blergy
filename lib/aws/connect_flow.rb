module Blergy
  module AWS
    class ConnectFlow < Base
      attr_accessor :instance
      attr_accessor :steps

      def initialize(instance, **hash)
      end

      def dump(target_directory, options)
        read_steps
        # dump_helper('production')
        # dump_helper('staging')
      end

      def self.read(instance)
        instance.flows={}
        instance.list_connect_flow_modules(instance.connect_instance_id).each do |hash|
          instance.flows[hash["Name"]]=ConnectFlow.new(instance, hash)
        end
      end
    end
  end
end
