module Blergy
  module AWS
    class LambdaFunctionAssociation < Base

      def initialize(instance, arn)
        self.instance=instance
        self.attributes= {arn: arn}
        attributes[:name]=attributes[:arn].match(%r(arn:aws:(?:.+):(?:.+):(.+)))[1]
      end

      def modules_dir
        "#{instance.target_directory}/modules/connect/lambda_function_associations"
      end

      def terraform_resource_name
        "aws_connect_lambda_function_association"
      end

      def write_config_templates(f)
        attributes[:config].each do |config|
          f.write <<-TEMPLATE
  config {
    day = "#{config[:day]}"

    end_time {
      hours   = #{config[:end_time][:hours]}
      minutes = #{config[:end_time][:minutes]}
    }

    start_time {
      hours   = #{config[:start_time][:hours]}
      minutes = #{config[:start_time][:minutes]}
    }
  }
          TEMPLATE
        end
      end

      def lambda_terraform_id
        "aws_lambda_function.#{label}.id"
      end

      def write_templates
        FileUtils.mkpath(modules_dir)
        File.open("#{modules_dir}/#{label}.tf",'w') do |f|
          f.write <<-TEMPLATE
resource "#{terraform_resource_name}"{
  instance_id  = "${aws_connect_instance.connect.id}"
  function_arn         = "${#{lambda_terraform_id}}"
  tags = local.tags
}
          TEMPLATE
        end
      end

      def self.read(instance)
        instance.lambda_function_associations={}
        instance.with_rate_limit do |client|
          client.list_lambda_functions(instance_id: instance.connect_instance_id).lambda_functions.each do |arn|
            instance.lambda_function_associations[arn]=self.new(instance, arn)
          end
        end
      end
    end
  end
end

