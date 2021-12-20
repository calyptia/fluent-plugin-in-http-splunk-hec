# fluent-plugin-in-http-splunk-hec

[Fluentd](https://fluentd.org/) input plugin to do mimicking Splunk HTTP HEC endpoint.

This plugin provides Splunk HTTP HEC endpoint aggragator plugins.

## Installation

### RubyGems

```
$ gem install fluent-plugin-in-http-splunk-hec
```

### Bundler

Add following line to your Gemfile:

```ruby
gem "fluent-plugin-in-http-splunk-hec"
```

And then execute:

```
$ bundle
```

## Configuration

* See also: [Input Plugin Overview](https://docs.fluentd.org/v/1.0/input#overview)

* See also: [HttpInput Plugin Overview](https://docs.fluentd.org/v/1.0/httpinput#overview)

## Fluent::Plugin::HttpSplunkHecInput

### Plugin helpers

* [parser](https://docs.fluentd.org/v/1.0/plugin-helper-overview/api-plugin-helper-parser)
* [compat_parameters](https://docs.fluentd.org/v/1.0/plugin-helper-overview/api-plugin-helper-compat_parameters)
* [event_loop](https://docs.fluentd.org/v/1.0/plugin-helper-overview/api-plugin-helper-event_loop)
* [server](https://docs.fluentd.org/v/1.0/plugin-helper-overview/api-plugin-helper-server)

* See also: [Input Plugin Overview](https://docs.fluentd.org/v/1.0/input#overview)

#### Configuration (Inherited from in\_http plugin)

|parameter|type|description|default|
|---|---|---|---|
|port|integer (optional)|The port to listen to.|`9880`|
|bind|string (optional)|The bind address to listen to.|`0.0.0.0`|
|body_size_limit|size (optional)|The size limit of the POSTed element. Default is 32MB.|`33554432`|
|keepalive_timeout|time (optional)|The timeout limit for keeping the connection alive.|`10`|
|backlog|integer (optional)|||
|add_http_headers|bool (optional)|Add HTTP_ prefix headers to the record.||
|add_remote_addr|bool (optional)|Add REMOTE_ADDR header to the record.||
|blocking_timeout|time (optional)||`0.5`|
|cors_allow_origins|array (optional)|Set a allow list of domains that can do CORS (Cross-Origin Resource Sharing)||
|cors_allow_credentials|bool (optional)|Tells browsers whether to expose the response to frontend when the credentials mode is "include".||
|respond_with_empty_img|bool (optional)|Respond with empty gif image of 1x1 pixel.||
|use_204_response|bool (optional)|Respond status code with 204.||
|dump_error_log|bool (optional)|Dump error log or not|`true`|
|add_query_params|bool (optional)|Add QUERY_ prefix query params to record||
|authorization_token|string (optional)|Handle Authroization header authentication with specified secret||

#### Configuration (Implemented)

|parameter|type|description|default|
|---|---|---|---|
|splunk_token|string (required)|Specify Splunk Authroization header token||

#### \<parse\> section (optional) (multiple)

#### Configuration (Overrided)

|parameter|type|description|default|
|---|---|---|---|
|@type| (optional)||`none`|

## Fluent::Plugin::ConcatenatedSplunkJSONFilter

### Plugin helpers

* [record_accessor](https://docs.fluentd.org/v/1.0/plugin-helper-overview/api-plugin-helper-record_accessor)

* See also: [Filter Plugin Overview](https://docs.fluentd.org/v/1.0/filter#overview)

#### Configuration

|parameter|type|description|default|
|---|---|---|---|
|message_key|string (optional)|message key|`message`|
|time_key|string (optional)|timestamp key|`time`|

## Integrated configuration Example

This plugin can handle Splunk HEC HTTP requests with the following configuration:

```aconf
<source>
  @type http_splunk_hec
  bind 0.0.0.0
  port 8088
  body_size_limit 32MB
  keepalive_timeout 10
  # backlog 0
  add_http_headers false
  splunk_token YOUR_SPLUNK_HTTP_HEC_TOKEN
  <parse>
    @type none
  </parse>
</source>

<filter services.collector>
  @type concatenated_splunk_json
</filter>

# And other data pipeline
```

### Advanced Usage

`in_http_splunk_hec` can be combined `fluent-plugin-cmetrics` to forward ingested Splunk metric records from mimicking Splunk HTTP HEC endpoint.

When you want to use the below Splunk HTTP HEC aggregator, you have to install `fluent-plugin-cmetrics` before you use that.

This plugin also can aggregate and the latter data pipeline can forward Splunk metric events with the following configuration:

```aconf
<source>
  @type http_splunk_hec
  bind 0.0.0.0
  port 8089
  body_size_limit 32MB
  keepalive_timeout 10
  # backlog 0
  add_http_headers false
  # Use the actual Splunk HTTP HEC endpoint token
  splunk_token <<YOUR_SPLUNK_HEC_TOKEN>>
  <parse>
    @type none
  </parse>
</source>

<filter services.collector>
  @type concatenated_splunk_json
</filter>

<match services.collector>
  @type copy
  <store>
    @type rdkafka2
    brokers <<BROKER_URL:BROKER_PORT>>
    topic services.collector
    default_topic services.collector
    use_event_time true
    required_acks 1
    <format>
      # This plugin is included in `fluent-plugin-cmetrics`.
      @type cmetrics_splunk_metric_payload
      host_key host
      cmetrics_name_key $.fields.metric_name
      cmetrics_value_key $.fields._value
      # Specifying the below parameter and `$.fields` in `<fields>` plugin custom directive,
      # out_rdkafka2 can send Splunk metrics style records into Kafka.
      #
      # To remove the `$.fields` prefix from Splunk dimensions,
      # This parameter should be true.
      only_use_last_field_keys true
      <fields>
        $.fields
      </fields>
    </format>
    <buffer>
      @type memory
      flush_interval 10s
    </buffer>
  </store>
  <store>
    @type stdout
  </store>
</match>
```

## Copyright

* Copyright(c) 2021- Calyptia Inc.
* License
  * Apache License, Version 2.0
