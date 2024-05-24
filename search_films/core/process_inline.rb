# frozen_string_literal: true

class ProcessInline
  def self.call(inline_query:)
    new(inline_query: inline_query).call
  end

  def initialize(inline_query:,
    search_films: Queries::SearchFilmsByQuery,
    get_film: Queries::GetFilmById,
    upload_poster_to_bucket: Queries::UploadPosterToBucket
  )
    @inline_query = inline_query
    @inline_query_id =inline_query["id"]
    @query = inline_query["query"]
    @search_films = search_films
    @get_film = get_film
    @upload_poster_to_bucket = upload_poster_to_bucket
  end

  # @returns { 
  #    statusCode: 200, 
  #    body: body
  #  }
  def call
    puts "[#{self.class}] inline Query: #{inline_query.inspect}"
    return status_code_200 if sent_via_bot?

    resp = Cache.get_item(client: dynamodb, query: query, type: :inline)
    if resp.has_key?(:ok)
      puts "[#{self.class}] got result from cache for query: \"#{query}\" #{resp[:ok]}"
      return response_to_client(resp[:ok])
    end
    
    resp = get_from_external_service
    return resp[:error] if resp.has_key?(:error)

    films = resp[:ok]
    body = films.map.with_index(1) do |film, index|
      prepare_body(film: film, index: index)
    end
    puts "[#{self.class}] body for all films: #{body.inspect}"
    Cache.put_item(client: dynamodb, film: body, query: query, type: :inline)
    puts "[#{self.class}] result for query: \"#{query}\" was cached for 1 week as #{body.inspect}"
    response_to_client(body)
    status_code_200
  end

  private

  attr_reader :inline_query, :inline_query_id, :query, :search_films, :get_film, :upload_poster_to_bucket

  # @returns true
  # @returns false
  def sent_via_bot?
    result = inline_query&.dig("is_bot") == true
    if result
      puts "#{self.class} The message has been sent via bot."
    end
    result
  end

  # @returns {:ok, []}
  # @returns {:error, ""}
  def get_from_external_service
    films = search_films.call(query: query)&.first(5)
    
    result = if films.nil?
      zero_results_error
    else
      {ok: films}
    end
    puts "[#{self.class}] get_from_external_service returns: #{result.inspect}"
    result
  end

  def status_code_200
    {
      statusCode: 200,
      body: "OK"
    }
  end

  def response_to_client(body)
    uri = URI.parse("https://api.telegram.org/bot#{Secrets.call.telegram_bot_token}/answerInlineQuery")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
  
    data = {
      inline_query_id: inline_query_id,
      results: body
    }
  
    json_data = data.to_json
  
    headers = {'Content-Type' => 'application/json'}
  
    http.post(uri.path, json_data, headers)
  end
  
  def zero_results_error
    {
      error: response_error_to_client("0 results was found, try again.")
    }
  end

  def prepare_body(film:, index:)
    poster_path = film["poster_path"]&.delete("/")
    upload_poster_to_bucket.call(s3_key: poster_path) if !poster_path.nil?

    body = {
      id: index,
      type: "article",
      title: film["original_title"],
      description: "#{film["genres"]} | #{film["popularity"]} | #{film["overview"]}",
      input_message_content: {
        message_text: build_description(film),
        parse_mode: "Markdown"
      }
    }

    if !poster_path.nil?
      presigned_url = create_presigned_url(s3_key: poster_path)
      puts "[#{self.class}] presigned_url: #{presigned_url.inspect}"
      body.merge!(thumbnail_url: presigned_url.to_s)
    end

    puts "[#{self.class}] prepare_body returns: #{body.inspect}"
    body
  end

  # @returns { 
  #    statusCode: 200, 
  #    body: body
  #  }
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

  def create_presigned_url(s3_key:)
    url, _ = signer.presigned_request(:get_object, bucket: ENV["IMAGES_BUCKET"], key: s3_key, expires_in: 604_800)
    puts "[#{self.class}] create_presigned_url: #{url.inspect}"
    url
  end

  def build_description(film)
    result = "Top movie by popularity for your query\n"
    result += "*Original Title *: #{film["original_title"]}\n"
    result += "*Overview*: #{film["overview"]}\n" 
    result += "*Popularity*: #{film["popularity"]}\n"
    result += "*Release Date*: #{film["release_date"]}\n"
    result += "*Genre*: #{film["genres"]&.first&.dig("name")}\n"
    result += "*Poster*: [Poster](#{film["url"].to_s})\n"

    puts "[#{self.class}] build_description returns: #{result.inspect}"
    result
  end

  def signer
    @signer ||= Aws::S3::Presigner.new 
  end

  def dynamodb
    @dynamodb ||= Aws::DynamoDB::Client.new
  end
end
