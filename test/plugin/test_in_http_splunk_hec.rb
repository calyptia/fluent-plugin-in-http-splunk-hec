require "helper"
require 'timecop'
require 'net/http'
require 'securerandom'
require "fluent/plugin/in_http_splunk_hec.rb"

# This test code is heavily based on:
# https://github.com/fluent/fluentd/blob/5281e2be0d4d4802a14fa5d33a779ebe995214f6/test/plugin/test_in_http.rb
class HttpSplunkHecInputTest < Test::Unit::TestCase
  class << self
    def startup
      socket_manager_path = ServerEngine::SocketManager::Server.generate_path
      @server = ServerEngine::SocketManager::Server.open(socket_manager_path)
      ENV['SERVERENGINE_SOCKETMANAGER_PATH'] = socket_manager_path.to_s
    end

    def shutdown
      @server.close
    end
  end

  def setup
    Fluent::Test.setup
    @port = unused_port
  end

  def teardown
    Timecop.return
    @port = nil
  end

  def splunk_token
    @token ||= SecureRandom.uuid
  end

  def config
    %[
      port #{@port}
      bind "127.0.0.1"
      body_size_limit 10m
      keepalive_timeout 5
      respond_with_empty_img true
      use_204_response false
    ]
  end

  $test_in_http_connection_object_ids = []
  $test_in_http_content_types = []
  $test_in_http_content_types_flag = false
  module ContentTypeHook
    def initialize(*args)
      @io_handler = nil
      super
    end
    def on_headers_complete(headers)
      super
      if $test_in_http_content_types_flag
        $test_in_http_content_types << self.content_type
      end
    end

    def on_message_begin
      super
      if $test_in_http_content_types_flag
        $test_in_http_connection_object_ids << @io_handler.object_id
      end
    end
  end

  class Fluent::Plugin::HttpInput::Handler
    prepend ContentTypeHook
  end

  def test_post_with_splunk_token
    d = create_driver(config + %[
          splunk_token "#{splunk_token}"
        ])

    time = event_time("2011-01-02 13:14:15 UTC")
    Timecop.freeze(Time.at(time))
    event = ["tag1", time, {"a"=>1}]
    res_code = nil
    res_header = nil

    d.run do
      res = post("/#{event[0]}", {"a"=>1}, {"Authorization"=>"Splunk #{splunk_token}"})
      res_code = res.code
    end
    assert_equal(
      {
        response_code: "200",
        tag: event[0],
        valid_record_p: true
      },
      {
        response_code: res_code,
        tag: d.events[0][0],
        valid_record_p: d.events[0][2].has_key?("message")
      }
    )
  end

  def test_post_with_invalid_splunk_token
    d = create_driver(config + %[
          splunk_token "#{splunk_token}"
        ])

    time = event_time("2011-01-02 13:14:15 UTC")
    Timecop.freeze(Time.at(time))
    event = ["tag1", time, {"a"=>1}]
    res_code = nil
    res_header = nil

    d.run do
      res = post("/#{event[0]}", {"a"=>1}, {"Authorization"=>"Splunk invalid_token"})
      res_code = res.code
    end
    assert_equal(
      {
        response_code: "403",
        event: [],
      },
      {
        response_code: res_code,
        event: []
      }
    )
  end

  def get(path, params, header = {})
    http = Net::HTTP.new("127.0.0.1", @port)
    req = Net::HTTP::Get.new(path, header)
    http.request(req)
  end

  def options(path, params, header = {})
    http = Net::HTTP.new("127.0.0.1", @port)
    req = Net::HTTP::Options.new(path, header)
    http.request(req)
  end

  def post(path, params, header = {}, &block)
    http = Net::HTTP.new("127.0.0.1", @port)
    req = Net::HTTP::Post.new(path, header)
    block.call(http, req) if block
    if params.is_a?(String)
      unless header.has_key?('Content-Type')
        header['Content-Type'] = 'application/octet-stream'
      end
      req.body = params
    else
      unless header.has_key?('Content-Type')
        header['Content-Type'] = 'application/x-www-form-urlencoded'
      end
      req.set_form_data(params)
    end
    http.request(req)
  end

  private

  def create_driver(conf=config)
    Fluent::Test::Driver::Input.new(Fluent::Plugin::HttpSplunkHecInput).configure(conf)
  end
end
