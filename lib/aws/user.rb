module Blergy
  module AWS
    class User < Base

      def initialize(instance, hash)
        self.instance=instance
        self.attributes={}.merge instance.client.describe_user(instance_id: instance.connect_instance_id, user_id: hash['id']).user
      end

      def self.modules_dir(instance)
        "#{instance.target_directory}/environments/#{instance.environment}/users"
      end
      def self.resource_name
        :users
      end
      def self.dependencies
        [:routing_profiles_map, :security_profiles_map]
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
      def for_staging(staging_instance)
        name = instance.security_profile_by_id_for(attributes[:security_profile_ids][0]).name
        security_profile_id = staging_instance.security_profile_by_name_for(name).id
        name = instance.routing_profile_by_id_for(attributes[:routing_profile_id]).name
        puts attributes

        routing_profile_id = "2e32a83a-68a2-4eae-a7de-2e63c33e58f4" #staging_instance.routing_profile_by_name_for(name).id
        {
          "Username": attributes[:username],
          "Password": "Good2Eat!",
          "IdentityInfo": {
              "FirstName": attributes[:identity_info][:first_name],
              "LastName": attributes[:identity_info][:last_name]
          },
          "PhoneConfig": {
              "PhoneType": attributes[:phone_config][:phone_type],
              "AutoAccept": attributes[:phone_config][:auto_accept],
              "AfterContactWorkTimeLimit": attributes[:phone_config][:after_contact_work_time_limit],
          },
          "SecurityProfileIds": [
            security_profile_id
          ],
          "RoutingProfileId": routing_profile_id
       }
      end

      def create(staging_instance)
        cmd = %Q{
          aws connect create-user \\
          --instance-id #{staging_instance.connect_instance_id} \\
          --cli-input-json "#{for_staging(staging_instance).to_json.gsub('"','\"')}"
        }
        puts cmd
        result = JSON.parse(`#{cmd}`)
        puts result
        instance.with_rate_limit do
           instance.users[result["UserArn"]]=self.class.new(instance, {'id' => result["UserId"]})
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
