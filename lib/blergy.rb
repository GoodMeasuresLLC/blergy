# frozen_string_literal: true

require_relative "blergy/version"
require 'thor'
module Blergy
  # just a hack to reload all files when they've changed. Instead of doing it properly via spring or whatnot.
  def self.reload!
    load 'blergy.rb'
    load 'aws/base.rb'
    load 'aws/instance.rb'
    load 'aws/contact_flow.rb'
    load 'aws/hours_of_operation.rb'
    load 'aws/queue_quick_connect.rb'
    load 'aws/queue.rb'
    load 'aws/lambda_function_association.rb'
    load 'aws/lambda_function.rb'
    load 'aws/user.rb'
    load 'aws/security_profile.rb'
    load 'aws/routing_profile.rb'
  end

  class Error < StandardError; end
  class Main < Thor
    option :region, required: false, default: 'us-east-1'
    desc "dump", "dump connect-instance-id target-directory --region us-east-1"
    long_desc <<-DOC
      Example:
      blergy dump 03103f71-db62-4f61-9432-4bfae356b3e3 my-terraform-project-dir
      --region defaults to us-east-1
    DOC
    def dump(connect_instance='03103f71-db62-4f61-9432-4bfae356b3e3', target_directory='/Users/rob/Projects/GoodMeasures/connect')
      check_aws_config
      AWS::Instance.new(connect_instance, target_directory, options[:region] || 'us-east-1').dump(options)
    end

    option :region, required: false, default: 'us-east-1'
    desc "migrate_part_1", "migrate_part_1 production-instance staging-instance  my-terraform-project-dir --region us-east-1"
    def migrate_part_1(production='03103f71-db62-4f61-9432-4bfae356b3e3', staging='1be1f972-2ec2-47db-b57a-8152c0098abe', target_directory='/Users/rob/Projects/GoodMeasures/connect')
      production=AWS::Instance.new(production, target_directory, options[:region] || 'us-east-1')
      production.migrate_part_1(staging)
    end

    option :region, required: false, default: 'us-east-1'
    desc "migrate_part_2", "migrate_part_2 production-instance staging-instance  my-terraform-project-dir --region us-east-1"
    def migrate_part_2(production='03103f71-db62-4f61-9432-4bfae356b3e3', staging='1be1f972-2ec2-47db-b57a-8152c0098abe', target_directory='/Users/rob/Projects/GoodMeasures/connect')
      production=AWS::Instance.new(connect_instance, target_directory, options[:region] || 'us-east-1')
      production.migrate_part_2(staging)
    end

    option :region, required: false, default: 'us-east-1'
    desc "import", "migrate staging-instance  my-terraform-project-dir --region us-east-1"
    def import(staging='1be1f972-2ec2-47db-b57a-8152c0098abe')
      staging=AWS::Instance.new(staging,target_directory='/Users/rob/Projects/GoodMeasures/connect','us-east-1','staging')
      staging.import
    end
    desc "debug", "stuff"
    def debug(connect_instance='03103f71-db62-4f61-9432-4bfae356b3e3', target_directory='/Users/rob/Projects/GoodMeasures/connect')
      path = '/Users/rob/Projects/GoodMeasures/connect/modules/connect/flows/_00_Routing_Flow.json'
      file = File.read(path)
      hash=JSON.parse(file)
      variablize_content(hash)
      # AWS::Instance.new(connect_instance, "#{target_directory}/terraform", options[:region] || 'us-east-1')
    end

    no_commands do
      def check_aws_config
        unless ENV['AWS_ACCESS_KEY_ID'] && ENV['AWS_SECRET_ACCESS_KEY']
          puts <<-DOC
          You must define AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY in your environment,
          or define in on the command line, like so:

          AWS_ACCESS_KEY_ID=DqAwDNtd12343134 AWS_ACCESS_KEY_ID=AKIAJWS12343134 blerg dump 12343134 my-terraform-project
          DOC
          exit(-1)
        end
      end
    end
  end
end
