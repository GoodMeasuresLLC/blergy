require 'aws-sdk'
module Blergy
  module AWS
    class Base
      attr_accessor :target_directory
      attr_accessor :attributes
      attr_accessor :variables
      attr_accessor :instance

      def self.credentials
        @credentials ||= Aws::Credentials.new(ENV['AWS_ACCESS_KEY_ID'],ENV['AWS_SECRET_ACCESS_KEY'])
      end

      def client_for(region)
        @client ||= Aws::Connect::Client.new(region: region, credentials: self.class.credentials)
      end

      def client
        @client
      end

      def name
        attributes["name"] || attributes[:name]
      end
      def label
        fred = name.gsub(/\W+/,'_').gsub(/_$/,'')
        fred = "_#{fred}" if(fred =~ /^\d/) # terraform variables can't start with a digit
        fred
      end

      def terraform_id
        "#{terraform_resource_name}.#{label}.id"
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
