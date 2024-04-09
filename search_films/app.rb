require 'json'
require 'uri'
require 'net/http'
require 'aws-sdk-s3'
require 'securerandom'

API_PATH = "https://api.themoviedb.org/3".freeze
IMAGE_PATH = "https://image.tmdb.org/t/p/w500".freeze

def lambda_handler(event:, context:)
  puts "event: #{event.inspect}"
  body = JSON.parse(event["body"])
  
  if body.key?("message")
    process_message(body["message"])
  elsif body.key?("inline_query")
    process_inline_query(body["inline_query"])
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

def process_inline_query(inline_query)
  inline_query_id = inline_query["id"]
  puts "inline_query_id: #{inline_query_id.inspect}"
  text = inline_query["query"]
  puts "requested text: #{text.inspect}"

  films = search_films_by_query(text)
  
  top_five = films["results"]&.first(5)

  puts "top 5: #{top_five.inspect}"
  array_of_films = build_films_data(top_five)
  puts "response: #{array_of_films.inspect}"
  response_inline_to_client(inline_query_id, array_of_films)
end

def response_inline_to_client(inline_query_id, movies)
  results =  build_results_for_inline_query(movies)

  puts "results for inline query: #{results.inspect}"
  uri = URI.parse("https://api.telegram.org/bot#{telegram_token}/answerInlineQuery")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  data = {
    inline_query_id: inline_query_id,
    results: results
  }

  puts "data: #{data.inspect}"
  json_data = data.to_json

  headers = {'Content-Type' => 'application/json'}

  response = http.post(uri.path, json_data, headers)

  puts "-------------------------------------------------------------------"
  puts "response for inline: #{response.body}"
  
  status_code_200
end

def process_message(message)
  return status_code_200 if sent_via_bot?(message)

  chat_id = message["chat"]["id"]
  text = message["text"]
  puts "requested text: #{text.inspect}"
  films = search_films_by_query(text)
  
  top_five = films["results"]&.first(1)
  return response_error_to_client(chat_id, "0 results was found, try again.") if top_five.empty?

  puts "top 5: #{top_five.inspect}"
  array_of_films = build_films_data(top_five)
  puts "response: #{array_of_films.inspect}"
  response_message_to_client(chat_id, array_of_films.first)
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

def search_films_by_query(query)
  puts "text: #{query.inspect}"
  url = URI("#{API_PATH}/search/movie?query=#{query}&include_adult=false&language=en-US&page=1&sort_by=popularity.desc")
  http = Net::HTTP.new(url.host, url.port)
  http.use_ssl = true
  request = init_request_and_build_headers(url)
  response = http.request(request)
  body = JSON.parse(response.read_body)
  puts "body: #{body.inspect}"
  body
end

def build_films_data(films)
  puts "===== 0"
  films.map do |f|
    film_id = f["id"]
    puts "===== 1"
    url = URI("#{API_PATH}/movie/#{film_id}?language=en-US")
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    request = init_request_and_build_headers(url)
    response = http.request(request)
    puts "===== 2"
    body = JSON.parse(response.read_body)
    puts "body: #{body.inspect}"
    next if body["success"] == false

    file_key = body["poster_path"]&.delete("/")
    bucket_image_path = upload_poster_to_bucket(file_key) if !file_key.nil?
    puts "bucket_image_path: #{bucket_image_path.inspect}"

    data = default_data(body)
    if !file_key.nil?
      data.merge!(url: create_presigned_url(file_key))
    end
    data
  end
end

def default_data(body)
  {
    id: body["id"],
    original_title: body["original_title"],
    overview: body["overview"],
    popularity: body["popularity"],
    release_date: body["release_date"],
    genres: body["genres"]&.first&.dig("name"),
  }
end

def init_request_and_build_headers(url)
  request = Net::HTTP::Get.new(url)
  request["Accept"] = 'application/json'
  request["Authorization"] = tmdb_token
  request
end

def s3
  @s3 ||= Aws::S3::Client.new 
end

def signer
  @signer ||= Aws::S3::Presigner.new 
end

def upload_poster_to_bucket(poster_path)
  url = URI("#{IMAGE_PATH}/#{poster_path}")
  http = Net::HTTP.new(url.host, url.port)
  http.use_ssl = true
  request = init_request_and_build_headers(url)
  response = http.request(request)
  puts "image: #{response.inspect}"
  upload_poster_to_s3(response.body, poster_path)
end

def upload_poster_to_s3(image, poster_path)
  s3.put_object(
    bucket: bucket,
    key: poster_path,
    body: image
  )
end

def create_presigned_url(file_key)
  url, _ = signer.presigned_request(:get_object, bucket: ENV["IMAGES_BUCKET"], key: file_key, expires_in: 3600)
  puts "url: #{url.inspect}"
  url
end

def bucket
  @bucket ||= ENV["IMAGES_BUCKET"]
end

def build_results_for_inline_query(movies)
  movies.map.with_index(1) do |movie, index|
    {
      id: index,
      type: "article",
      title: movie[:original_title],
      thumbnail_url: movie[:url].to_s,
      description: "#{movie[:genres]} | #{movie[:popularity]} | #{movie[:overview]}",
      input_message_content: {
        message_text: create_message_text_for_inline(movie),
        parse_mode: "Markdown"
      }
    }
  end
end

def create_message_text_for_inline(movie)
  puts "movie: #{movie.inspect}"
  result = "*Original Title *: #{movie[:original_title]}\n"
  result += "*Overview*: #{movie[:overview]}\n" 
  result += "*Popularity*: #{movie[:popularity]}\n"
  result += "*Release Date*: #{movie[:release_date]}\n"
  result += "*Genre*: #{movie[:genres]}\n"
  result += "*Poster*: [Poster](#{movie[:url].to_s})\n"
  result
end

def create_description(movie)
  puts "movie: #{movie.inspect}"
  result = "Top movie by popularity for your query\n"
  result += "*Original Title *: #{movie[:original_title]}\n"
  result += "*Overview*: #{movie[:overview]}\n" 
  result += "*Popularity*: #{movie[:popularity]}\n"
  result += "*Release Date*: #{movie[:release_date]}\n"
  result += "*Genre*: #{movie[:genres]}\n"
  result
end

def sent_via_bot?(message)
  result = message&.dig("via_bot")&.dig("is_bot") == true
  if result
    puts "The message has been sent via bot."
  end
  result
end

def tmdb_token
  "Bearer eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiI5ZDE4MGQxN2YwZDE2MThhZmQ4NWE0OGU1OTVlNDdiMiIsInN1YiI6IjY1ZmQ5YWZlMTk3ZGU0MDE4NjE2YTM4ZCIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.Sj2KOJSxLM83-C4TNysC-r1A5AUtklxfJznYkE0fdsg"
end

def telegram_token
  "7147614064:AAEzUCzOKvm0Ct-WCv-o65xxHHSW_5KM94A"
end
