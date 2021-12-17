#
# Copyright 2021- Calyptia Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "fluent/plugin/input"
require "fluent/plugin/in_http"

module Fluent
  module Plugin
    class HttpSplunkHecInput < Fluent::Plugin::HttpInput
      Fluent::Plugin.register_input("http_splunk_hec", self)

      desc 'Specify Splunk Authroization header token'
      config_param :splunk_token, :string, secret: true

      config_section :parse do
        config_set_default :@type, 'none'
      end

      private

      def on_server_connect(conn)
        handler = ::Fluent::Plugin::HttpInput::Handler.new(conn, @km, method(:on_request),
                              @body_size_limit, @format_name, log,
                              @cors_allow_origins, @cors_allow_credentials,
                              @add_query_params, @splunk_token)

        conn.on(:data) do |data|
          handler.on_read(data)
        end

        conn.on(:write_complete) do |_|
          handler.on_write_complete
        end

        conn.on(:close) do |_|
          handler.on_close
        end
      end

      class ::Fluent::Plugin::HttpInput::Handler
        def initialize(io, km, callback, body_size_limit, format_name, log,
                       cors_allow_origins, cors_allow_credentials, add_query_params, splunk_token)
          @io = io
          @km = km
          @callback = callback
          @body_size_limit = body_size_limit
          @next_close = false
          @format_name = format_name
          @log = log
          @cors_allow_origins = cors_allow_origins
          @cors_allow_credentials = cors_allow_credentials
          @idle = 0
          @add_query_params = add_query_params
          @splunk_token = splunk_token
          @km.add(self)

          @remote_port, @remote_addr = io.remote_port, io.remote_addr
          @parser = Http::Parser.new(self)
        end

        def on_headers_complete(headers)
          expect = nil
          size = nil
          authorization = nil

          if @parser.http_version == [1, 1]
            @keep_alive = true
          else
            @keep_alive = false
          end
          @env = {}
          @content_type = ""
          @content_encoding = ""
          headers.each_pair {|k,v|
            @env["HTTP_#{k.gsub('-','_').upcase}"] = v
            case k
            when /\AExpect\z/i
              expect = v
            when /\AContent-Length\Z/i
              size = v.to_i
            when /\AContent-Type\Z/i
              @content_type = v
            when /\AContent-Encoding\Z/i
              @content_encoding = v
            when /\AConnection\Z/i
              if v =~ /close/i
                @keep_alive = false
              elsif v =~ /Keep-alive/i
                @keep_alive = true
              end
            when /\AOrigin\Z/i
              @origin  = v
            when /\AX-Forwarded-For\Z/i
              # For multiple X-Forwarded-For headers. Use first header value.
              v = v.first if v.is_a?(Array)
              @remote_addr = v.split(",").first
            when /\AAccess-Control-Request-Method\Z/i
              @access_control_request_method = v
            when /\AAccess-Control-Request-Headers\Z/i
              @access_control_request_headers = v
            when /\AAuthorization\Z/i
              # For Splunk Authrozation header verification only.
              authorization = v
            end
          }
          if expect
            if expect == '100-continue'.freeze
              if !size || size < @body_size_limit
                send_response_nobody("100 Continue", {})
              else
                send_response_and_close("413 Request Entity Too Large", {}, "Too large")
              end
            else
              send_response_and_close("417 Expectation Failed", {}, "")
            end
          end
          if authorization
            # For Splunk Authrozation header verification only.
            if "Splunk #{@splunk_token}" != authorization
              send_response_and_close("403 Forbidden", {}, "Authorization Failed")
            end
          end
        end
      end
    end
  end
end
