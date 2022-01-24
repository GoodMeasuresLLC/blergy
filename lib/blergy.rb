# frozen_string_literal: true

require_relative "blergy/version"
require 'thor'
module Blergy
  class Error < StandardError; end
  class Main < Thor
    option :filter, type: :array
    option :region, default: 'us-east-1'
    desc "dump", "dump connect-instance-id target-directory [--filter <regex1> <regex2> ...] --region us-east-1"
    long_desc <<-DOC
      --filter lets you filter out AWS connect flows that you don't want, like test flows.
      Example:
      blerg dump 12343134 my-terraform-project --filter TEST ^Hacking
      --region defaults to us-east-1
    DOC
    def dump(connect_instance='03103f71-db62-4f61-9432-4bfae356b3e3', target_directory='/Users/rob/Projects/GoodMeasures/terraform')
      check_aws_config
      options[:filter].each do |name|
        say "Hello there #{name}"
      end if options[:filter]
      AWS::Instance.new(connect_instance).dump(target_directory, options)
    end

    no_commands do
      def check_aws_config
        unless ENV['AWS_ACCESS_KEY_ID'] && ENV['AWS_SECRET_ACCESS_KEY']
          puts <<-DOC
          You must define AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY in your environment,
          or define in on the command line, like so:

          AWS_ACCESS_KEY_ID=DqAwDNtd12343134 AWS_ACCESS_KEY_ID=AKIAJWS12343134 blerg dump 12343134 my-terraform-project
          DOC
        end
        puts "ENV['AWS_ACCESS_KEY_ID'] missing" unless ENV['AWS_ACCESS_KEY_ID']
      end
    end
  end
end
