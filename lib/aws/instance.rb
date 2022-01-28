module Blergy
  module AWS
    class Instance < Base
      attr_accessor :connect_instance_id
      attr_accessor :flows
      attr_accessor :region
      attr_accessor :hours_of_operations
      attr_accessor :queues
      attr_accessor :queue_quick_connects


      def initialize(connect_instance_id, target_directory, region)
        self.connect_instance_id = connect_instance_id
        self.target_directory=target_directory
        self.region = region
        client_for(region)
      end

      def modules_dir
        "#{target_directory}/modules/connect"
      end


      def environment_dir(stage)
        "#{target_directory}/environments/#{stage}"
      end

      def queue_for(arn)
        queues[arn]
      end
      def queue_quick_connect_for(arn)
        queue_quick_connects[arn]
      end
      def hours_of_operation_for(arn)
        hours_of_operations[arn]
      end
      def contact_flow_for(contact_flow_arn)
# for example: arn:aws:connect:us-east-1:201706955376:instance/03103f71-db62-4f61-9432-4bfae356b3e3/contact-flow/fc7e607a-a89f-45b9-8346-0d9a497d03b1
        flows[contact_flow_arn]
      end

      def dump_queues
        client.list_queues(instance_id: connect_instance_id).queue_summary_list.each_with_index do |hash, index|
          begin
            File.open("../queues/queue_#{hash.name}.json","w") do |f|
              q=client.describe_queue(instance_id: connect_instance_id, queue_id: hash.id).queue
              f.write JSON.pretty_generate(q.to_h)
            end
          rescue
            puts "cant find #{hash.id} - #{hash.name}"
          end
        end
      end

      def dump(options)
        dump_queues
        raise "hell"
        self.attributes = client.describe_instance({instance_id: connect_instance_id}).instance
        # puts "attributes=#{attributes.instance_alias}"
        store_stage_variable("instance_alias",attributes.instance_alias)
        HoursOfOperation.read(self) if false
        ContactFlow.read(self) if false
        Queue.read(self) if false
        QueueQuickConnect.read(self) if false
        # contact-flow-modules, i guess.

# looks like the prompts are not directly managed via Connect, instead they are simply
# uploaded??? They are certainly referenced in the ContactFlows via name.
# but there is no terraform resource for them
#
# puts "prompts!"
# client.list_prompts(instance_id: connect_instance_id).prompt_summary_list.each_with_index do |hash, index|
#   puts "\nprompt[#{index} #{hash.to_h}"
# end
# which gives only:
#  {:id=>"f518d0fe-3cb7-470e-9c39-32a68e8418a8",
#  :arn=>"arn:aws:connect:us-east-1:201706955376:instance/03103f71-db62-4f61-9432-4bfae356b3e3/prompt/f518d0fe-3cb7-470e-9c39-32a68e8418a8",
#  :name=>"Music - Rock_EverywhereTheSunShines_Inst.wav"
#  }


# lambdas can be dumped but I think that all of the infrastructure for converting a javascript file into a .zip
# file for uploading to lambda might be in the gm-microservices project.
        # dump lambdas
        # dump queues
        write_templates
        # write_variables('common')
        # write_variables('production')
        # write_variables('staging')
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

locals {
  tags = {
    environment = var.environment,
    project = "connect"
  }
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
  tags = local.tags
}
          TEMPLATE
        end
        flows.values.map(&:write_templates)
        hours_of_operations.values.map(&:write_templates)
        queue_quick_connects.values.map(&:write_templates)
        queues.values.map(&:write_templates)
        # dump a json of all prompts, since that's all I can do:
        File.write("#{modules_dir}/prompts.json",JSON.pretty_generate(client.list_prompts(instance_id: connect_instance_id).prompt_summary_list.to_h))
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
