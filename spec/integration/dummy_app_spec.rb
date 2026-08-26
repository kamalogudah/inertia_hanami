# frozen_string_literal: true

RSpec.describe "DummyApp" do
  include Rack::Test::Methods

  def app
    Hanami.app
  end

  it "boots as a real Hanami app and serves a request end-to-end" do
    get "/"

    expect(last_response.status).to eq(200)
    expect(last_response.body).to include("Hello from DummyApp")
  end
end
