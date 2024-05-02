require 'aws-sdk-s3'
require 'json'
require 'uri'
require 'net/http'
require 'aws-sdk-dynamodb'
require 'aws-sdk-secretsmanager'

require_relative 'core/process_message'
require_relative 'core/process_inline'
require_relative 'core/secrets'

require_relative 'core/cache'
require_relative 'core/queries/search_films_by_query'
require_relative 'core/queries/upload_poster_to_bucket'
require_relative 'core/queries/get_film_by_id'

def lambda_handler(event:, context:)
  puts "[#{self.class}] Event: #{event.inspect}"
  body = JSON.parse(event["body"])
  
  if body.key?("message")
    ProcessMessage.call(message: body["message"])
  elsif body.key?("inline_query")
    ProcessInline.call(inline_query: body["inline_query"])
  else
    status_code_200
  end
rescue => e
  puts e.inspect
  status_code_200
end

def status_code_200
  {
    statusCode: 200,
    body: "OK"
  }
end





