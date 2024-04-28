# frozen_string_literal: true

require 'json'
require 'uri'
require 'net/http'

module Queries
  class UploadPosterToBucket
    IMAGE_PATH = "https://image.tmdb.org/t/p/w500".freeze

    def self.call(poster_path)
      new(poster_path).call
    end

    def initialize(poster_path)
      @poster_path = poster_path
    end

    def call
      url = URI("#{IMAGE_PATH}/#{poster_path}")
      response = get_request(url)
      image = response.body
      upload_poster_to_s3(image, poster_path)
    end

    private

    attr_reader :poster_path

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
    
    def upload_poster_to_s3(image, poster_path)
      s3.put_object(
        bucket: bucket,
        key: poster_path,
        body: image
      )
    end

    def s3
      @s3 ||= Aws::S3::Client.new 
    end

    def bucket
      @bucket ||= ENV["IMAGES_BUCKET"]
    end
  end
end