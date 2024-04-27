# frozen_string_literal: true

require 'aws-sdk-dynamodb'
require_relative 'core/cache'

class ProcessMessage  
  def self.call(message:)
    new(message: message).call
  end

  def initialize(message:)
    @message = message
    @chat_id = message["chat"]["id"]
    @text = message["text"]
  end

  def call
    return status_code_200 if sent_via_bot?

    resp = Cache.get_item(client: dynamodb, query: text, type: :message)

    film_data = if resp.has_key?(:ok)
      { ok: resp[:ok] }
    else
      get_from_external_service
    end

    if film_data.has_key?(:ok)
      response_message_to_client(film_data)
    else
      film_data[:error]
    end
  end

  private

  attr_reader :message, :text, :chat_id

  def sent_via_bot?
    result = message&.dig("via_bot")&.dig("is_bot") == true
    if result
      puts "The message has been sent via bot."
    end
    result
  end

  def get_from_external_service
    films = search_films_by_query(text)
    
    top_five = films["results"]&.first(1)
    return {error: response_error_to_client(chat_id, "0 results was found, try again.")} if top_five.empty?
  
    film = build_films_data(top_five).first
  
    Cache.put_item(client: dynamodb, film: film, query: text)
  
    {ok: film}
  end

  def status_code_200
    {
      statusCode: 200,
      body: "OK"
    }
  end

  def response_message_to_client(chat_id, movie)
    body = {
      method: "sendMessage",
      chat_id: chat_id,
      text: create_description(movie),
      parse_mode: "Markdown",
    }
  
    if !movie[:url].nil?
      body.merge!(link_preview_options: {
        url: movie[:url]
      })
    end
  
    { 
      statusCode: 200, 
      body: body.to_json
    }
  end

  def response_error_to_client(chat_id, text)
    { 
      statusCode: 200, 
      body: {
        method: "sendMessage",
        chat_id: chat_id,
        text: text
      }.to_json
    }
  end

  def dynamodb
    @dynamodb ||= Aws::DynamoDB::Client.new
  end
end
