require "helper"
require 'timecop'
require 'net/http'
require 'securerandom'
require "fluent/plugin/filter_concatenated_splunk_json.rb"

class ConcatenatedSplunkJSONFilterTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
    @data = File.read(File.join(__dir__, "fixture", "actual_http_body.json")).chomp!
  end

  def teardown
    @data = nil
  end

  CONFIG = %[
    message_key message
    time_key time
  ]

  test "parsing simple body w/o time_key" do
    d = create_driver
    d.run(default_tag: "test") do
      d.feed(Fluent::EventTime.now, {"message" => '{"event":"Hello, world!", "sourcetype":"manual"}'})
    end
    assert do
      d.filtered.size >= 1
    end
  end

  test "parsing condensed body" do
    d = create_driver
    d.run(default_tag: "test") do
      d.feed(Fluent::EventTime.now, {"message" => @data})
    end
    assert do
      d.filtered.size > 1
    end
  end

  private

  def create_driver(conf=CONFIG)
    Fluent::Test::Driver::Filter.new(Fluent::Plugin::ConcatenatedSplunkJSONFilter).configure(conf)
  end
end
