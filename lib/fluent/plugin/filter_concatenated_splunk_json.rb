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

require "fluent/plugin/filter"
require "fluent/event"
require "fluent/time"
require "time"

module Fluent
  module Plugin
    class ConcatenatedSplunkJSONFilter < Fluent::Plugin::Filter
      Fluent::Plugin.register_filter("concatenated_splunk_json", self)

      helpers :record_accessor

      desc "message key"
      config_param :message_key, :string, default: "message"
      desc "timestamp key"
      config_param :time_key, :string, default: "time"

      def configure(conf)
        super
        @message_accessor = record_accessor_create(@message_key)
        @timestamp_accessor = record_accessor_create(@time_key)
      end

      def parse_splunk_timestamp(timestamp)
        if !timestamp.nil?
          timestamp = Float(timestamp)
          Fluent::EventTime.from_time(Time.at(timestamp.to_r))
        else
          Fluent::EventTime.now
        end
      end

      def filter_stream(tag, es)
        new_es = Fluent::MultiEventStream.new
        es.each do |time, record|
          message = @message_accessor.call(record)
          text = message.gsub("}{", "},{")
          array = Yajl.load("[" + text + "]")
          array.each do |element|
            time = @timestamp_accessor.call(element)
            new_es.add(parse_splunk_timestamp(time), element)
          end
        end
        new_es
      end
    end
  end
end
