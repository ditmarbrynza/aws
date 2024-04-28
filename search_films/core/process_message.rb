# frozen_string_literal: true

require 'aws-sdk-dynamodb'
require_relative 'cache'
require_relative 'queries/search_films_by_query'

class ProcessMessage  
  def self.call(message:)
    new(message: message).call
  end

  def initialize(message:, search_films: Queries::SearchFilmsByQuery)
    @message = message
    @chat_id = message["chat"]["id"]
    @query = message["text"]
    @search_films = search_films
  end

  def call
    return status_code_200 if sent_via_bot?

    resp = Cache.get_item(client: dynamodb, query: query, type: :message)
    return resp[:ok] if resp.has_key?(:ok)
    
    resp = get_from_external_service

  end

  private

  attr_reader :message, :query, :chat_id, :search_films

  def sent_via_bot?
    result = message&.dig("via_bot")&.dig("is_bot") == true
    if result
      puts "#{self.class} The message has been sent via bot."
    end
    result
  end

  def get_from_external_service
    result = search_film.call(query: query)
    
    films = result["results"]&.first(1)
    return zero_results_error if films.empty?
  
    film = build_films_data(film_id: films.first["id"])
  
    # Cache.put_item(client: dynamodb, film: film, query: query)
  
    {ok: film}
  end

  def status_code_200
    {
      statusCode: 200,
      body: "OK"
    }
  end

  def zero_results_error
    {
      error: response_error_to_client("0 results was found, try again.")
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

  def response_error_to_client(text)
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
