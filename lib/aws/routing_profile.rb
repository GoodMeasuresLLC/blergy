module Blergy
  module AWS
    class RoutingProfile < Base

      def initialize(instance, hash)
        self.instance=instance
        self.attributes={}.merge instance.client.describe_routing_profile(instance_id: instance.connect_instance_id, routing_profile_id: hash['id']).routing_profile
      end

      def modules_dir
        "#{instance.target_directory}/production/connect/routing_profile"
      end

      def write_templates
        FileUtils.mkpath(modules_dir)
        File.open("#{modules_dir}/#{label}.json",'w') do |f|
          f.write attributes.to_json
        end
      end

      def self.read(instance)
        instance.routing_profiles={}
        instance.with_rate_limit do |client|
          client.list_routing_profiles(instance_id: instance.connect_instance_id).routing_profile_summary_list.each do |hash|
            instance.with_rate_limit do
              instance.routing_profiles[hash.arn]=self.new(instance, hash)
            end
          end
        end
      end
    end
  end
end
