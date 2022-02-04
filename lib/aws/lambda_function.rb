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
        "#{instance.target_directory}/lambda_source"
      end

      def compilation_dir
        "#{instance.target_directory}/compiled"
      end

      def modules_dir
        "#{instance.target_directory}/modules/lambdas"
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
      def write_templates
        FileUtils.mkpath(source_dir)
        target_dir="#{source_dir}/#{name}"
        FileUtils.mkpath(target_dir)
        zipfile="#{source_dir}/#{name}.zip"
        compiled_zip_path="#{compilation_dir}/#{name}.zip"
        build_script="#{target_dir}/build.sh"
        uri = URI(location)
        res = Net::HTTP.get_response(uri)
        File.open(zipfile,'wb') do |outfile|
          outfile.write(res.body)
        end
        `unzip -o #{zipfile} -d #{target_dir}`
        FileUtils.rm(zipfile)
        File.open(build_script,'w') do |f|
          f.write <<-EOS
#!/bin/bash
zip #{target_dir} -d #{compiled_zip_path}
          EOS
        end
        FileUtils.chmod("+x",build_script)
        FileUtils.mkpath(modules_dir)
        FileUtils.mkpath(compilation_dir)
        File.open("#{modules_dir}/#{label}.tf",'w') do |f|
          f.write <<-TEMPLATE
resource "#{terraform_resource_name}" "#{label}"{
  function_name="#{name}"
  description  = "#{attributes[:description]}"
  tags         =local.tags
  runtime      ="#{attributes[:runtime]}"
  role         ="arn:aws:iam::201706955376:role/lambda_basic_execution"
  handler      ="${attributes[:handler]}"
  timeout      = #{attributes[:timeout]}
  memory_size  = #{attributes[:memory_size]}
  package_type ="Zip"
  layers = [aws_lambda_layer_version.layers.arn]
  filename     = "#{compiled_zip_path}"
  source_code_hash = filebase64sha256("#{compiled_zip_path}")
}

  depends_on = [aws_cloudwatch_log_group.log_group]
}

resource "aws_cloudwatch_log_group" "log_group" {
  name = "/aws/lambda/#{name}"
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
# of which should be putting a zip file in the compiled director
find *  -name 'build.sh' -depth 1 -print -exec {} \;
          EOS
        end
        FileUtils.chmod("+x",build_script)
      end


      def self.read(instance)
        install_build_script(instance)
        instance.lambda_functions={}
        instance.lambda_function_associations.values.each do |tmp|
          instance.lambda_functions[tmp.name]=self.new(instance, tmp.name)
        end
      end
    end
  end
end

