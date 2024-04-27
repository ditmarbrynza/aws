# frozen_string_literal: true

class SearchFilm

  def search_films_by_query(query)
    url = URI("#{API_PATH}/search/movie?query=#{query}&include_adult=false&language=en-US&page=1&sort_by=popularity.desc")
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    request = init_request_and_build_headers(url)
    response = http.request(request)
    body = JSON.parse(response.read_body)
    body
  end

  def init_request_and_build_headers(url)
    request = Net::HTTP::Get.new(url)
    request["Accept"] = 'application/json'
    request["Authorization"] = tmdb_token
    request
  end

end
