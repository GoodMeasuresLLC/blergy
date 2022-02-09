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

      def environment
        instance.environment
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

      def self.write_templates(instance, modules_dir, resource_name, list)
        FileUtils.mkpath(modules_dir)
        File.open("#{modules_dir}/variables.tf",'w') do |f|
          list.each do |var|
            f.write %Q{variable "#{var}" {type = map(any)}\n}
          end
          f.write <<-TEMPLATE
variable "connect_instance_id" {}
variable "tags" {}
          TEMPLATE
        end
        File.open("#{modules_dir}/outputs.tf",'w') do |f|
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
