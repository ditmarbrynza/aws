module Queries
  class GetFilm
    API_PATH = "https://api.themoviedb.org/3".freeze
    GET_FILM_BY_ID = ->(id){ URI("#{API_PATH}/movie/#{id}?language=en-US") }

    def call
      new(id: film_id).call
    end

    def initialize(id:)
      @id = id
    end

    def call
      url = GET_FILM_BY_ID.call(id)
      response = get_request(url)
      body = JSON.parse(response.read_body)
      puts "[#{self.class}] returns #{body.inspect}"
      body
    end

    private

    def get_request(url)
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      request = init_request_and_build_headers(url)
      http.request(request)
    end

    def init_request_and_build_headers(url)
      request = Net::HTTP::Get.new(url)
      request["Accept"] = 'application/json'
      request["Authorization"] = secrets_client.call.tmdb_token
      request
    end
  end
end