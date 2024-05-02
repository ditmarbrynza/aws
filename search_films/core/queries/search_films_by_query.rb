# frozen_string_literal: true

require 'json'
require 'uri'
require 'net/http'
require_relative '../secrets'

module Queries
  class SearchFilmsByQuery
    API_PATH = "https://api.themoviedb.org/3".freeze
    GET_FILMS_BY_QUERY_URL = ->(query_params) { URI("#{API_PATH}/search/movie?#{query_params}") }

    def self.call(query:)
      new(query: query).call
    end

    def initialize(query:, secrets_client: Secrets)
      @query = query
      @secrets_client = secrets_client
    end

    # @returns [{},{} ... {}]
    def call
      url = GET_FILMS_BY_QUERY_URL.call(query_params(query))
      response = get_request(url)
      body = JSON.parse(response.read_body)
      puts "[#{self.class}] returns #{body["results"].inspect}"
      body["results"]
    end

    private

    attr_reader :query, :secrets_client

    def get_request(url)
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      request = init_request_and_build_headers(url)
      http.request(request)
    end

    def query_params(query)
      "query=#{query}&include_adult=false&language=en-US&page=1&sort_by=popularity.desc"
    end

    def init_request_and_build_headers(url)
      request = Net::HTTP::Get.new(url)
      request["Accept"] = 'application/json'
      request["Authorization"] = secrets_client.call.tmdb_token
      request
    end
  end
end
