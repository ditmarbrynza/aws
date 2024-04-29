require_relative 'core/process_message'

def lambda_handler(event:, context:)
  puts "[#{self.class}] Event: #{event.inspect}"
  body = JSON.parse(event["body"])
  puts "[#{self.class}] Event: #{body["message"].inspect}"
  
  if body.key?("message")
    ProcessMessage.call(message: body["message"])
  elsif body.key?("inline_query")
    # process_inline_query(body["inline_query"])
    status_code_200
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





