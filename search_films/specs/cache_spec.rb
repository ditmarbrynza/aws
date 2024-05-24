require_relative '../core/cache'
require 'json'

RSpec.describe Cache do
  describe "#get_item" do
    describe "returns :ok" do
      let(:cached_data) {
        { "item" => { "expired_at" => (Time.now.utc + 7 * 24 * 60 * 60).to_i, "data" => {} } }
      }
      let(:client) { double('client') }

      before do
        allow(client).to receive(:get_item) { cached_data }
      end

      it do
        resp = described_class.get_item(client: client, query: "batman", type: :message)
        expect(resp.has_key?(:ok)).to eq(true)
      end
    end

    describe "returns :error" do
      let(:client) { double('client') }

      before do
        allow(client).to receive(:get_item) { {} }
      end

      it do
        resp = described_class.get_item(client: client, query: "batman", type: :message)
        expect(resp.has_key?(:error)).to eq(true)
      end
    end
  end
end
