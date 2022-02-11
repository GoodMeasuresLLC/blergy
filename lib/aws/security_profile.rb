module Blergy
  module AWS
    class SecurityProfile < Base

      def initialize(instance, hash)
        self.instance=instance
        json=`aws connect describe-security-profile --security-profile-id #{hash['id']} --instance-id #{instance.connect_instance_id}`
         # {:SecurityProfile=>
         # {"Id"=>"469ac895-3473-4bdc-b6c7-7c6e77da44f4",
         #  "OrganizationResourceId"=>"03103f71-db62-4f61-9432-4bfae356b3e3",
         #  "Arn"=>"arn:aws:connect:us-east-1:201706955376:instance/03103f71-db62-4f61-9432-4bfae356b3e3/security-profile/469ac895-3473-4bdc-b6c7-7c6e77da44f4",
         #  "SecurityProfileName"=>"Admin",
         #  "Description"=>"An administrator can perform all actions available.",
         #  "Tags"=>{}}}
        self.attributes = JSON.parse(json)["SecurityProfile"].transform_keys do |k|
          case k
          when "Id" then :id
          when "OrganizationResourceId" then :organization_resource_id
          when "Arn" then :arn
          when "SecurityProfileName" then :name
          when "Description" then :description
          when "Tags" then :tags
          end
        end
      end

      def terraform_module_name
        "module.connect.module.#{accessor_name}.#{terraform_resource_name}.#{label}"
      end

      def self.modules_dir(instance)
        "#{instance.target_directory}/modules/connect/security_profiles"
      end
      def self.resource_name
        :security_profiles
      end
      def self.dependencies
        []
      end

      def terraform_key
        "security_profile_id"
      end

      def terraform_resource_name
        "aws_connect_security_profile"
      end

      def write_templates
        File.open("#{modules_dir}/#{label}.tf",'w') do |f|
          f.write <<-TEMPLATE
resource "#{terraform_resource_name}" "#{label}" {
  instance_id  = "${#{instance.terraform_reference}}"
  name         = "#{attributes[:name]}"
  description  = "#{attributes[:description]}"
          TEMPLATE
          if attributes[:permissions]
            f.write <<-TEMPLATE
permissions  = [#{attributes[:permissions].map{|a|%Q{"#{a}"}}.join(",")}]
            TEMPLATE
          end
          f.write <<-TEMPLATE
  tags = var.tags
}
          TEMPLATE
        end
      end

      def self.read(instance)
        instance.security_profiles={}
        instance.with_rate_limit do |client|
          client.list_security_profiles(instance_id: instance.connect_instance_id).security_profile_summary_list.each do |hash|
            instance.with_rate_limit do
              instance.security_profiles[hash.arn]=self.new(instance, hash)
            end
          end
        end
      end
    end
  end
end
