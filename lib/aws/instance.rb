module Blergy
  module AWS
    class Instance < Base
      attr_accessor :connect_instance_id
      attr_accessor :flows
      attr_accessor :hours_of_operations
      attr_accessor :queues
      attr_accessor :queue_quick_connects
      attr_accessor :lambda_function_associations
      attr_accessor :lambda_functions
      attr_accessor :users
      attr_accessor :security_profiles
      attr_accessor :routing_profiles



      def initialize(connect_instance_id, target_directory, region)
        self.connect_instance_id = connect_instance_id
        self.target_directory=target_directory
        self.region = region
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
      def queue_by_id_for(id)
        queues.detect{|k,v| k =~ /#{id}$/}&.at(1)
      end
      def queue_quick_connect_for(arn)
        queue_quick_connects[arn]
      end
      def hours_of_operation_for(arn)
        hours_of_operations[arn]
      end
      def hours_of_operation_by_id_for(id)
        hours_of_operations.detect{|k,v| k =~ /#{id}$/}&.at(1)
      end
      def contact_flow_for(contact_flow_arn)
# for example: arn:aws:connect:us-east-1:201706955376:instance/03103f71-db62-4f61-9432-4bfae356b3e3/contact-flow/fc7e607a-a89f-45b9-8346-0d9a497d03b1
        flows[contact_flow_arn]
      end

      def contact_flow_by_id_for(contact_flow_id)
# for example: arn:aws:connect:us-east-1:201706955376:instance/03103f71-db62-4f61-9432-4bfae356b3e3/contact-flow/fc7e607a-a89f-45b9-8346-0d9a497d03b1
        flows.detect{|k,v| k =~ /#{contact_flow_id}$/}&.at(1)
      end

      def lambda_function_for(arn)
# for example: arn:aws:connect:us-east-1:201706955376:instance/03103f71-db62-4f61-9432-4bfae356b3e3/contact-flow/fc7e607a-a89f-45b9-8346-0d9a497d03b1
        lambda_functions[arn]
      end

      def dump_queues
        with_rate_limit do |client|
          client.list_queues(instance_id: connect_instance_id).queue_summary_list.each_with_index do |hash, index|
            next unless hash.name
            File.open("../queues/queue_#{hash.name}.json","w") do |f|
              with_rate_limit do |client|
                q=client.describe_queue(instance_id: connect_instance_id, queue_id: hash.id).queue
                f.write JSON.pretty_generate(q.to_h)
              end
            end
          end
        end
      end

      def dump_contact_flow_modules
        with_rate_limit do |client|
          client.list_contact_flow_modules(instance_id: connect_instance_id).list_contact_flow_module_summary_list.each_with_index do |hash, index|
            next unless hash.name
            File.open("../contact_flow_modules/contact_flow_module_#{hash.name}.json","w") do |f|
              with_rate_limit do |client|
                q=client.describe_contact_flow_module(instance_id: connect_instance_id, queue_id: hash.id).queue
                f.write JSON.pretty_generate(q.to_h)
              end
            end
          end
        end
      end

      def dump_lambda_functions
        File.open("lambda_function_assocations.json","w") do |f|
          with_rate_limit do |client|
            client.list_lambda_functions(instance_id: connect_instance_id).lambda_functions.each do |arn|
              f.write "#{arn}\n"
              with_rate_limit do |client|
                resp=LambdaFunction.new(self,"berlg").client.get_function(function_name: arn)
                puts "resp.configuration.function_name=#{resp.configuration.function_name}"
                puts "resp.configuration.runtime=#{resp.configuration.runtime}"
                puts "resp.code.repository_type=#{resp.code.repository_type}"
                puts "resp.code.location=#{resp.code.location}"
              end
            end
          end
        end
      end
      def dump_users
      end

      def dump(options)
        # dump_lambda_functions
        # raise "hell"
        self.attributes = client.describe_instance({instance_id: connect_instance_id}).instance
        # puts "attributes=#{attributes.instance_alias}"
        store_stage_variable("instance_alias",attributes.instance_alias)
        Queue.read(self)
        QueueQuickConnect.read(self)
        HoursOfOperation.read(self)
        ContactFlow.read(self)
        LambdaFunctionAssociation.read(self)
        LambdaFunction.read(self)
# YOU WERE HERE -
# * make things environment based.
# * finish caller id configurations

        # caller ids
        # make queues, QueueQuickConnect be environment based
        # users as well, except for production
        User.read(self)
        RoutingProfile.read(self)
        SecurityProfile.read(self)

# environments in gm-microservices do not contain different services, they are instead different AWS accounts
# we want a connect AWS project
# we want to only support py and js lambdas projects, probably not worth supporting ruby
# modules are being used to reuse lambda resource configuration for different AWS S3 resource sources.
# we want a minimal staging implementation, with only a few queues and users
# we want a cleaned up set of production users. No Christina, for example.

        # contact-flow-modules - there are none.
# users (specific to Connect)
# here are the basic parameters for a user:
# --phone-config <value>
# [--directory-user-id <value>]
# --security-profile-ids <value>
# --routing-profile-id <value>
# [--hierarchy-group-id <value>]

# which means we need security and routing profiles
# routing profiles can be created via the CLI, but not via terraform
# security profiles can be created via the CLI, and via terraform beta.
#

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
# lambdas are a simple association between the instance and the arn of the lambda.
# that is supported by ResourceLambdaFunctionAssociation() terraform in beta.
# so for each lambda you need to
# 1. get the list of arns
# 2. create the actual lambda resource in a different place aws_lambda_function
#
        write_environments
        write_templates
      end

      def write_environments
        %W(
        queues
        queue_quick_connects
        users
        outbound_caller_config
        ).each {|dir|
          %W{common staging production}.each do |stage|
            FileUtils.mkpath("#{environment_dir(stage)}/#{dir}")
            File.open("#{environment_dir(stage)}/main.tf",'w') do |f|
              f.write <<-TEMPLATE
terraform {
  backend "s3" {
    bucket = "com.goodmeasures.connect-#{stage}-terraform"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.region
}

module "staging" {
  source = "../../.."

  # items from ../common outputs
  # NOTE - to acquire these values run `terraform output` from the ../common dir
  account_id = var.account_id
  name_prefix = var.name_prefix
  region = var.region
  vpc_id = var.vpc_id
  vpc_endpoint_id = var.vpc_endpoint_id
  subnet_ids = var.subnet_ids
  lambda_role_arn = var.lambda_role_arn

  # items specific to this environment
  environment = var.environment
}
              TEMPLATE
            end
          end
        }
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
        # lambda_function_associations.values.map(&:write_templates)
        lambda_functions.values.map(&:write_templates)
        flows.values.map(&:write_templates)
        hours_of_operations.values.map(&:write_templates)
        queue_quick_connects.values.map(&:write_templates)
        queues.values.map(&:write_templates)
        users.values.map(&:write_templates)
        routing_profiles.values.map(&:write_templates)
        security_profiles.values.map(&:write_templates)
        # dump a json of all prompts, since that's all I can do:
        File.write("#{modules_dir}/prompts.json",
          JSON.pretty_generate(
            client.list_prompts(instance_id: connect_instance_id).prompt_summary_list.map(&:to_h)))
      end
    end
  end
end

# dynamodb.

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
