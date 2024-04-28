# frozen_string_literal: true

require 'aws-sdk-secretsmanager'

class Secrets
  def self.call
    new.call
  end

  def tmdb_token
    "Bearer #{@tmdb_token}"
  end

  def telegram_bot_token
    @telegram_bot_token
  end

  def call
    init_secrets
    self
  end

  private

  def init_secrets
    client = Aws::SecretsManager::Client.new(region: 'eu-central-1')

    begin
      secret_values = client.get_secret_value(secret_id: 'aws_search_films_secrets')
    rescue StandardError => e
      puts "#{self.class} error: #{e.inspect}"
      raise e
    end

    secret = JSON.parse(secret_values.secret_string)
    @tmdb_token = secret["tmdb_token"]
    @telegram_bot_token = secret["telegram_bot_token"]
  end
end