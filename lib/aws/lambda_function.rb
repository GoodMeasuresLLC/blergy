module Blergy
  module AWS
    class LambdaFunction < Base
      attr_accessor :location

      def self.client_class
        Aws::Lambda::Client
      end

      def initialize(instance, name)
        self.instance=instance
        self.region = instance.region
        with_rate_limit do |client|
          resp=client.get_function(function_name: name)
          self.attributes={name: name}.merge(resp.configuration)
          self.location = resp.code.location
        end
      end

      def source_dir
        "$HERE/../../lambda_source"
      end

      def compilation_dir
        "$HERE/../../compiled"
      end

      def self.modules_dir(instance)
        "#{instance.target_directory}/modules/lambda_functions"
      end
      def self.resource_name
        :lambda_functions
      end
      def self.dependencies
        [:log_retention_days]
      end
      def terraform_key
        "arn"
      end

      def terraform_resource_name
        "aws_lambda_function"
      end

# resource "aws_lambda_function" "test_lambda" {
#   filename      = "lambda_function_payload.zip"
#   function_name = "lambda_function_name"
#   role          = aws_iam_role.iam_for_lambda.arn
#   handler       = "index.test"

#   # The filebase64sha256() function is available in Terraform 0.11.12 and later
#   # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
#   # source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
#   source_code_hash = filebase64sha256("lambda_function_payload.zip")

#   runtime = "nodejs12.x"

#   environment {
#     variables = {
#       foo = "bar"
#     }
#   }
# }
<<DOC
module "lambda" {
  source = "../lambda"
  environment = var.environment
  lambda_role_arn = var.lambda_role_arn
  function_name = var.lambda_function_name
  handler_name = var.handler_name
  lambda_runtime = var.lambda_runtime
  s3_bucket = var.s3_bucket
  // When we are syncing zip files with s3, refer to the s3 key via the resource, not via input
  // variables, so that resource dependencies are established (that is, the lambda resource will not
  // be created until the zip file is in s3)
  s3_key = var.source_file_path != "" ? element(aws_s3_bucket_object.source.*.key, 1) : var.s3_code_key
  s3_layers_key = var.layers_file_path != "" ? element(aws_s3_bucket_object.layers.*.key, 1) : var.s3_layers_key
  source_code_hash = var.source_file_path != "" ? filebase64sha256(var.source_file_path) : null
  layers_source_code_hash = var.layers_file_path != "" ? filebase64sha256(var.layers_file_path) : null
  lambda_git_sha1 = var.lambda_git_sha1
  elasticsearch_host = var.elasticsearch_host
  log_retention_days = var.log_retention_days
  execution_timeout_seconds = var.execution_timeout_seconds
  memory_size_megs = var.memory_size_megs
  subnet_ids = var.subnet_ids
  security_group_id = var.security_group_id
}

and then you get:
resp = client.get_function_configuration({
  function_name: "NamespacedFunctionName", # required
  qualifier: "Qualifier",
})

which has code.location, which I assume is the source code as a sha? Or, maybe a .zip file and needs unzipping?
- zip file that needs unzipping, all lambda functions are distributed as .zip files, since they may contain a directory structure

or equally,

resp = client.get_function({
  function_name: "NamespacedFunctionName", # required
  qualifier: "Qualifier",
})

which also returns configuration.code.location

It is possible the function_name can also be a ARN. It can be in the CLI.
DOC


      def ruby?
        attributes[:runtime] =~ /ruby/
      end

      def write_templates
        source_abs_dir="#{instance.target_directory}/lambda_source/#{label}"
        target_abs_dir="#{instance.target_directory}/compiled"
        FileUtils.mkpath(source_abs_dir)
        target_dir="#{source_dir}/#{label}"
        FileUtils.mkpath(target_abs_dir)
        zipfile_file=Tempfile.new
        zipfile = zipfile_file.path
        compiled_zip_path="#{compilation_dir}/#{label}.zip"
        build_script="#{source_abs_dir}/build.sh"
        uri = URI(location)
        res = Net::HTTP.get_response(uri)
        File.open(zipfile,'wb') do |outfile|
          outfile.write(res.body)
        end
        if(ruby?)
          File.open("#{source_abs_dir}/.ruby-version","w") do |f|
            f.write("2.7.1")
          end
          File.open("#{source_abs_dir}/Gemfile","w") do |f|
            f.write <<-TEMPLATE
source 'https://rubygems.org'

gem 'httparty'
gem 'json_pure'
gem 'mime-types-data'
gem 'json'
gem 'mime-types'
gem 'multi_xml'
            TEMPLATE
          end
          File.open(build_script,'w') do |f|
          f.write <<-EOS
#!/bin/bash
cd #{label}
rm -rf vendor
bundle config set --local path 'vendor/bundle'
bundle install
cd ..
zip -r ../compiled/#{label} #{label}
          EOS
        end
      else
          File.open(build_script,'w') do |f|
            f.write <<-EOS
#!/bin/bash
zip -r ../compiled/#{label} #{label}
            EOS
          end
        end
        `unzip -o #{zipfile} -d #{source_abs_dir}`
        FileUtils.rm(zipfile)
        FileUtils.chmod("+x",build_script)
        FileUtils.mkpath(modules_dir)
        FileUtils.mkpath(compilation_dir)
        attributes[:runtime]="ruby2.7" if ruby?
        attributes[:runtime]="nodejs14.x" if attributes[:runtime] =~ /nodejs/
        compiled_zip_relative_path = "../../compiled/#{label}.zip"
        File.open("#{modules_dir}/#{label}.tf",'w') do |f|
          f.write <<-TEMPLATE
resource "#{terraform_resource_name}" "#{label}"{
  function_name="#{name}-${var.tags["environment"]}"
  description  = "#{attributes[:description]}"
  tags         = var.tags
  runtime      ="#{attributes[:runtime]}"
  role         ="arn:aws:iam::201706955376:role/lambda_basic_execution"
  handler      ="#{attributes[:handler]}"
  timeout      = #{attributes[:timeout]}
  memory_size  = #{attributes[:memory_size]}
  package_type ="Zip"
  filename     = "#{compiled_zip_relative_path}"
  source_code_hash = filebase64sha256("#{compiled_zip_relative_path}")
  depends_on = [aws_cloudwatch_log_group.log_group-#{label}]
}

resource "aws_cloudwatch_log_group" "log_group-#{label}" {
  name = "/aws/lambda/#{name}-${var.tags["environment"]}"
  retention_in_days = var.log_retention_days
}

          TEMPLATE
        end
      end

      def self.install_build_script(instance)
        source_dir="#{instance.target_directory}/lambda_source"
        build_script="#{source_dir}/build.sh"
        FileUtils.mkpath(source_dir)
        File.open(build_script, "w") do |f|
          f.write <<-EOS
#!/bin/bash
# builds all the lambda functions by calling a build.sh script in their repo, the output
# of which should be putting a zip file in the compiled directory
export HERE=`pwd`
find *  -name 'build.sh' -depth 1 -print -exec {} \\;
          EOS
        end
        FileUtils.chmod("+x",build_script)
      end


      def self.read(instance)
        install_build_script(instance)
        instance.lambda_functions={}
        instance.lambda_function_associations.values.each do |tmp|
          instance.lambda_functions[tmp.attributes[:arn]]=self.new(instance, tmp.name)
        end
      end
    end
  end
end

