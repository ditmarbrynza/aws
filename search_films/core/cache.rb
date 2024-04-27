# frozen_string_literal: true

class Cache
  def self.get_item(client:, query:, type:)
    resp = client.get_item(
      table_name: ENV['DYNAMODB_TABLE'],
      key: {
        query: query
      }
    )
  
    puts "[#{self}] get_item request's response: #{JSON.pretty_generate(resp)}"
  
    result = if !resp["item"].nil? && resp["item"]&.dig("expired_at").to_i > Time.now.utc.to_i
      { ok: resp["item"]["data"] }
    else
      { error: :item_does_not_exist_or_invalid }
    end

    puts "[#{self}] get_item method returns: #{result.inspect}"

    result
  end

  def self.put_item(client:, film:, query:) 
    item = {
      query: query,
      data: film,
      expired_at: (Time.now.utc + 7 * 24 * 60 * 60).to_i
    }
  
    resp = client.put_item(
      table_name: ENV['DYNAMODB_TABLE'],
      item: item,
      return_consumed_capacity: 'INDEXES'
    )
  
    puts "[#{self}] put_item request's response: #{JSON.pretty_generate(resp)}"
  end
end