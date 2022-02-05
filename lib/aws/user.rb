module Blergy
  module AWS
    class User < Base

      def initialize(instance, hash)
        self.instance=instance
        self.attributes={}.merge instance.client.describe_user(instance_id: instance.connect_instance_id, user_id: hash['id']).user
      end

      def modules_dir
        "#{instance.target_directory}/environments/production/users"
      end

      def name
        attributes[:username]
      end

      def write_templates
        FileUtils.mkpath(modules_dir)
        File.open("#{modules_dir}/#{label}.json",'w') do |f|
          f.write JSON.pretty_generate(attributes)
        end
      end

      def self.read(instance)
        instance.users={}
        instance.with_rate_limit do |client|
          client.list_users(instance_id: instance.connect_instance_id).user_summary_list.each do |hash|
            instance.with_rate_limit do
              instance.users[hash.arn]=self.new(instance, hash)
            end
          end
        end
      end
    end
  end
end
