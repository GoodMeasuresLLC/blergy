module Blergy
  module AWS
    class Instance < Base
      attr_accessor :connect_instance_id
      attr_accessor :flows
      attr_accessor :region


      def initialize(connect_instance_id, target_directory, region)
        self.connect_instance_id = connect_instance_id
        self.target_directory=target_directory
        self.region = region
        client_for(region)
      end

      def modules_dir
        "#{target_directory}/modules/connect"
      end

      def dump(options)
        self.attributes = client.describe_instance({instance_id: connect_instance_id}).instance
        puts "attributes=#{attributes.instance_alias}"
        # ConnectFlow.read(self, connect_instance_id)
        store_stage_variable("instance_alias",attributes.instance_alias)
        write_templates
        write_variables('production')
        write_variables('staging')
      end

      def write_templates
        FileUtils.mkpath(modules_dir)
        File.open("#{modules_dir}/main.tf",'w') do |f|
          f.write <<-TEMPLATE
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }
  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = "#{region}"
}

resource "aws_connect_instance" "connect" {
  identity_management_type = "#{attributes.identity_management_type}"
  inbound_calls_enabled    = #{attributes.inbound_calls_enabled}
  instance_alias           = var.instance_alias
  outbound_calls_enabled   = #{attributes.outbound_calls_enabled}
  auto_resolve_best_voices_enabled = false
  contact_flow_logs_enabled = true
  early_media_enabled = false
}
          TEMPLATE
        end

      end

    end
  end
end

# {:id=>"03103f71-db62-4f61-9432-4bfae356b3e3"
# :arn=>"arn:aws:connect:us-east-1:201706955376:instance/03103f71-db62-4f61-9432-4bfae356b3e3"
# :identity_management_type=>"CONNECT_MANAGED"
# :instance_alias=>"[FILTERED]"
# :created_time=>2019-07-29 14:55:37 -0400
# :service_role=>"arn:aws:iam::201706955376:role/aws-service-role/connect.amazonaws.com/AWSServiceRoleForAmazonConnect_HBDQRkK8TkflREzD1NkM"
# :instance_status=>"ACTIVE"
# :status_reason=>nil
# :inbound_calls_enabled=>true
# :outbound_calls_enabled=>true}
