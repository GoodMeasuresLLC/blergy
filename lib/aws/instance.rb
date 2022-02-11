module Blergy
  module AWS
    class Instance < Base

      attr_accessor :connect_instance_id
      attr_accessor :contact_flows
      attr_accessor :hours_of_operations
      attr_accessor :queues
      attr_accessor :queue_quick_connects
      attr_accessor :lambda_function_associations
      attr_accessor :lambda_functions
      attr_accessor :users
      attr_accessor :security_profiles
      attr_accessor :routing_profiles
      attr_accessor :environment

      def target_directory
        @target_directory
      end

      def hours_of_operations
        # can't write a valid template unless you actually define some valid hours of operation, which is in the
        # config.
        @hours_of_operations.reject {|key, obj|(obj.attributes[:config]||[]).empty?}
      end

      def add_hours_of_operation(key, obj)
        @hours_of_operations[key]=obj
      end

      def queues
        @queues.reject {|key, obj|obj.attributes[:status] == 'DISABLED'}
      end

      def add_queue(key, obj)
        @queues[key]=obj
      end

      def initialize(connect_instance_id, target_directory=nil, region='us-east-1', environment='production')
        self.connect_instance_id = connect_instance_id
        self.target_directory=target_directory
        self.region = region
        self.environment = environment
        self.attributes={name: 'connect'}
        read
      end

      def label
        "connect"
      end

      def terraform_reference
        "var.connect_instance_id"
      end

      def terraform_key
        "id"
      end

      def terraform_resource_name
        "aws_connect_instance"
      end

      def modules_dir
        self.class.modules_dir(self)
      end

      def self.modules_dir(instance)
        "#{instance.target_directory}/modules/connect"
      end

      def environment_dir(stage)
        "#{target_directory}/environments/#{stage}"
      end

      def queue_for(arn)
        queues[arn]
      end
      def queue_by_id_for(id)
        return nil if id.nil?
        queues.detect{|k,v| k =~ /#{id}$/}&.at(1)
      end
      def queue_by_name_for(name)
        queues.values.detect{|v| v.name == name}
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
      def hours_of_operation_by_name_for(name)
        hours_of_operations.values.detect{|v| v.name == name}
      end
      def security_profile_by_id_for(id)
        security_profiles.detect{|k,v| k =~ /#{id}$/}&.at(1)
      end
      def security_profile_by_name_for(name)
        security_profiles.values.detect{|v| v.name == name}
      end
      def routing_profile_by_id_for(id)
        routing_profiles.detect{|k,v| k =~ /#{id}$/}&.at(1)
      end
      def routing_profile_by_name_for(name)
        routing_profiles.values.detect{|v| v.name == name}
      end

      def contact_flow_for(contact_flow_arn)
# for example: arn:aws:connect:us-east-1:201706955376:instance/03103f71-db62-4f61-9432-4bfae356b3e3/contact-flow/fc7e607a-a89f-45b9-8346-0d9a497d03b1
        contact_flows[contact_flow_arn]
      end
      def contact_flow_by_name_for(name)
        contact_flows.values.detect{|v| v.name == name}
      end
      def contact_flow_by_id_for(contact_flow_id)
        return nil if contact_flow_id.nil?
# for example: arn:aws:connect:us-east-1:201706955376:instance/03103f71-db62-4f61-9432-4bfae356b3e3/contact-flow/fc7e607a-a89f-45b9-8346-0d9a497d03b1
        contact_flows.detect{|k,v| k =~ /#{contact_flow_id}$/}&.at(1)
      end

      def user_by_name_for(user_name)
        users.values.detect{|v| v.name == user_name}
      end

      def user_by_id_for(id)
        users.values.detect{|v| v.id == id}
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
      # move the users, queue_quick_connects, queues, and routing profiles to staging.
      # for now, just migrate the users and routing profiles.
      def migrate_part_1(staging_instance_id)
        raise "this is not necessary any more"
        staging_instance = self.class.new(staging_instance_id, target_directory, region, :staging)
        contact_flows.each_pair {|k,v|
          v.instance=staging_instance
          staging_instance.flows[k] = v
        }
        queues.values.reject {|queue| staging_instance.queue_by_name_for(queue.name)}.each do |queue|
          queue.create(staging_instance)
        end
        Queue.write_templates(staging_instance)

        puts "you must now run terraform plan/apply so that the staging instance can harvest the queue ids, then run migrate_part_2"
      end

      def import
        hours_of_operations.values.map(&:import)
        contact_flows.values.map(&:import) #$ Connect Contact Flow
        security_profiles.values.map(&:import)
        # lambda_functions.values.map(&:import)
      end

      def migrate_part_2(staging_instance_id)
        staging_instance = self.class.new(staging_instance_id, target_directory, region, :staging)
        # routing_profiles.values.reject {|routing_profile| staging_instance.routing_profile_by_name_for(routing_profile.name)}.each do |routing_profile|
        #   routing_profile.create(staging_instance)
        # end
        users.values.reject {|user| staging_instance.user_by_name_for(user.name)}.each do |user|
          user.create(staging_instance)
        end
        puts "you must now run terraform plan/apply to finish the job"
      end

      def migrate_queue_quick_connects(staging_instance)
        staging_instance.queue_quick_connects={}
        queue_quick_connects.values.each do |obj|
          obj.create(staging_instance)
        end
      end

      def read
        self.attributes = client.describe_instance({instance_id: connect_instance_id}).instance
        # LambdaFunctionAssociation.read(self)
        # ContactFlow.read(self)
        # LambdaFunction.read(self)
        # Queue.read(self)
        QueueQuickConnect.read(self)
        # HoursOfOperation.read(self)
        User.read(self)
        RoutingProfile.read(self)
        SecurityProfile.read(self)
      end
      def dump(options)
        # dump_lambda_functions
        # raise "hell"
        # puts "attributes=#{attributes.instance_alias}"
        store_stage_variable("instance_alias",attributes.instance_alias)
        write_templates
      end

      def write_environments
        %W(
        queues
        queue_quick_connects
        users
        outbound_caller_config
        contact_flows
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

module "connect" {
  source = "../.."

  # items from ../common outputs
  # NOTE - to acquire these values run `terraform output` from the ../common dir
  account_id = var.account_id
  region = var.region
  vpc_id = var.vpc_id
  vpc_endpoint_id = var.vpc_endpoint_id
  lambda_role_arn = var.lambda_role_arn
  instance_alias = var.instance_alias
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
        File.open("#{modules_dir}/outputs.tf",'w') do |f|
          f.write <<-TEMPLATE
output "connect_instance_id" {
  value = aws_connect_instance.connect.id
}
          TEMPLATE
        end
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

resource "aws_connect_instance" "#{label}" {
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

        LambdaFunctionAssociation.write_templates(self)
        Queue.write_templates(self)
        if(false)
        QueueQuickConnect.write_templates(self)
        ContactFlow.write_templates(self)
        LambdaFunction.write_templates(self)
        HoursOfOperation.write_templates(self)
        SecurityProfile.write_templates(self)
          users.values.map(&:write_templates)
          routing_profiles.values.map(&:write_templates)
          # dump a json of all prompts, since that's all I can do:
          File.write("#{modules_dir}/prompts.json",
            JSON.pretty_generate(
              client.list_prompts(instance_id: connect_instance_id).prompt_summary_list.map(&:to_h)))
        end
      end
    end
  end
end
