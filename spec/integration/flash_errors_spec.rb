# frozen_string_literal: true

RSpec.describe "DummyApp flash/errors props" do
  include Rack::Test::Methods

  def app
    Hanami.app
  end

  def inertia_get(path)
    header "X-Inertia", "true"
    header "X-Inertia-Version", Hanami.app["inertia.config"].version
    get path
    JSON.parse(last_response.body)
  end

  it "surfaces errors stashed via share_inertia_errors and flash set before a redirect" do
    get "/set-flash-and-errors"
    expect(last_response.status).to eq(302)

    page = inertia_get("/")

    expect(page["props"]["errors"]).to eq("name" => ["is required"])
    expect(page["props"]["flash"]).to eq("notice" => "Saved!")
  end

  it "delivers errors and flash exactly once" do
    get "/set-flash-and-errors"

    inertia_get("/")
    page = inertia_get("/")

    expect(page["props"]).not_to have_key("errors")
    expect(page["props"]).not_to have_key("flash")
  end

  it "omits errors/flash entirely when nothing was stashed" do
    page = inertia_get("/")

    expect(page["props"]).not_to have_key("errors")
    expect(page["props"]).not_to have_key("flash")
  end
end
