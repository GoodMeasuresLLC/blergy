module Blergy
  module AWS
    class RoutingProfile < Base

      def initialize(instance, hash)
        self.instance=instance
        self.attributes={}.merge instance.client.describe_routing_profile(instance_id: instance.connect_instance_id, routing_profile_id: hash['id']).routing_profile
      end

      def modules_dir
        "#{instance.target_directory}/environments/#{environment}/routing_profile"
      end

      def write_templates
        FileUtils.mkpath(modules_dir)
        File.open("#{modules_dir}/#{label}.json",'w') do |f|
          f.write JSON.pretty_generate(attributes)
        end
      end

      def for_staging(staging_instance)
        name = instance.queue_by_id_for(attributes[:default_outbound_queue_id]).name
        queue_id = staging_instance.queue_by_name_for(name)
        {
            "Name": attributes[:name],
            "Description": attributes[:description],
            "DefaultOutboundQueueId": "",
            "MediaConcurrencies": attributes[:media_concurrencies].transform_keys {|k|
              case k
              when :channel then 'Channel'
              when :concurrency then 'Concurrency'
              end
            },
        }
      end

      def create(staging_instance)
        cmd = %Q{
          aws connect create-routing-profile \\
          --instance-id #{staging_instance.connect_instance_id} \\
          --cli-input-json #{for_staging(staging_instance).to_json}
        }
        puts cmd
        # result = JSON.parse(`#{cmd}`)
        # instance.with_rate_limit do
        #   instance.users[hash.arn]=self.new(instance, {'id' => result["UserId"]})
        # end
        raise "hell"
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
