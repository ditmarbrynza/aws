require_relative 'core/process_message'
require_relative 'core/process_inline'
require_relative 'core/secrets'


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





