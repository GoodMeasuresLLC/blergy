require 'aws-sdk'
module Blergy
  module AWS
    class Base
      attr_accessor :region
      attr_accessor :target_directory
      attr_accessor :attributes
      attr_accessor :variables
      attr_accessor :instance

      def self.credentials
        @credentials ||= Aws::Credentials.new(ENV['AWS_ACCESS_KEY_ID'],ENV['AWS_SECRET_ACCESS_KEY'])
      end

      def self.client_class
        Aws::Connect::Client
      end

# module.connect.module.flows.aws_connect_contact_flow
      def terraform_module_name
        "module.connect.module.#{accessor_name}.#{terraform_resource_name}"
      end
# terraform import aws_connect_queue.example f1288a1f-6193-445a-b47e-af739b2:c1d4e5f6-1b3c-1b3c-1b3c-c1d4e5f6c1d4e5
      def import
        cmd = "cd #{instance.target_directory}/environments/#{instance.environment};terraform import #{terraform_module_name} #{instance_id}:#{id}"
        puts cmd
        puts `#{cmd}`
      end



      def environment
        instance.environment
      end
      def target_directory
        instance.target_directory
      end

      def client
        @client ||= begin
          self.class.client_class.new(region: region, credentials: self.class.credentials)
        end
      end

      def name
        attributes["name"] || attributes[:name]
      end
      def arn
        attributes[:arn]
      end
      def id
        attributes[:id]
      end

      def instance_id
        instance.connect_instance_id
      end

      def label
        fred = name.gsub(/\W+/,'_').gsub(/_$/,'').downcase
        fred = "_#{fred}" if(fred =~ /^\d/) # terraform variables can't start with a digit
        fred
      end

      def with_rate_limit(&block)
        result=nil
        begin
          result=block.call(client)
        rescue Aws::Connect::Errors::TooManyRequestsException
          timeout = 1
          while(1)
            begin
              sleep(timeout)
              result=block.call(client)
              break
            rescue Aws::Connect::Errors::TooManyRequestsException
              timeout *= 2
            end
          end
        end
        result
      end

      def accessor_name
        self.class.resource_name
      end
      def self.resource_name
        raise "resource_name" # :contact_flows
      end
      def self.dependencies
        raise "dependencies" # [:queues_map, :lambda_functions_map]
      end
      def modules_dir
        self.class.modules_dir(instance)
      end

      def self.write_templates(instance)
        FileUtils.mkpath(modules_dir(instance))
        File.open("#{modules_dir(instance)}/variables.tf",'w') do |f|
          dependencies.each do |var|
            f.write %Q{variable "#{var}" {type = map(any)}\n}
          end
          f.write <<-TEMPLATE
variable "connect_instance_id" {}
variable "tags" {}
          TEMPLATE
        end
        File.open("#{modules_dir(instance)}/outputs.tf",'w') do |f|
          f.write <<-TEMPLATE
output "#{resource_name}_map" {
  value = {
    #{instance.send(resource_name).values.map {|obj| "\"#{obj.label}\" = #{obj.terraform_id}" }.join(",\n    ")}
  }
}
          TEMPLATE
        end
        fred = instance.send(resource_name).values
        puts "#{resource_name}: #{fred.size}"
        instance.send(resource_name).values.map(&:write_templates)
      end

      def terraform_id
        "#{terraform_resource_name}.#{label}.#{terraform_key}"
      end

      def terraform_reference
        "var.#{accessor_name}_map[\"#{label}\"]"
      end

      def store_stage_variable(variable, value,type='string')
        self.variables||={}
        self.variables['production']||={}
        variables['production'][variable] = {value: value, type: type}
      end

      def write_variables(stage)
        FileUtils.mkpath(environment_dir(stage))
        File.open("#{environment_dir(stage)}/variables.tf",'w') do |f|
          variables['production'].each_pair do |k,v|
            f.write <<-TEMPLATE
variable "#{k}" {
  type        = #{v[:type]}
  default     = "#{v[:value].gsub('production',stage)}"
}
            TEMPLATE
          end
        end
      end
    end
  end
end
