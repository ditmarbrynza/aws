# frozen_string_literal: true

module Queries
  class UploadPosterToBucket
    IMAGE_PATH = "https://image.tmdb.org/t/p/w500".freeze

    def self.call(s3_key:)
      new(s3_key: s3_key).call
    end

    def initialize(s3_key:, secrets_client: Secrets)
      @s3_key = s3_key
      @secrets_client = secrets_client
    end

    def call
      url = URI("#{IMAGE_PATH}/#{s3_key}")
      response = get_request(url)
      image = response.body
      upload_poster_to_s3(image)
    end

    private

    attr_reader :s3_key, :secrets_client

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
    
    def upload_poster_to_s3(image)
      s3.put_object(
        bucket: bucket,
        key: s3_key,
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
