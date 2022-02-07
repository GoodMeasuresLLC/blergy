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

      def accessor_name
        :lambda_function_associations
      end

      def terraform_resource_name
        "aws_connect_lambda_function_association"
      end

      def lambda_terraform_id
        "aws_lambda_function.#{label}.id"
      end

      def self.write_templates(instance, modules_dir, resource_name, references)
        FileUtils.mkpath(modules_dir)
        File.open("#{modules_dir}/variables.tf",'w') do |f|
          f.write <<-TEMPLATE
variable "connect_instance_id" {}
variable "lambda_functions_map" {type = map(any)}
variable "tags" {}
          TEMPLATE
        end
        instance.send(resource_name).values.map(&:write_templates)
      end

      def write_templates
        FileUtils.mkpath(modules_dir)
        lambda_function = instance.lambda_function_for(attributes[:arn])
        File.open("#{modules_dir}/#{label}.tf",'w') do |f|
          f.write <<-TEMPLATE
resource "#{terraform_resource_name}"{
  instance_id  = var.connect_instance_id
  function_arn         = #{lambda_function.terraform_reference}
  tags = var.tags
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

