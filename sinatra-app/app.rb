# inspired by https://github.com/open-telemetry/opentelemetry-demo/blob/main/src/emailservice/email_server.rb

require 'sinatra'
require "sinatra/reloader"
require 'net/http'

configure do
  enable :reloader
end

# Small monkey patch to allow "force" opentelemetry to use a trace_id passed
# as HTTP Header, or generated in another place.
module OpenTelemetry
  module Trace
    class SpanContext
      def force_trace_id=(new_trace_id)
        @trace_id = new_trace_id
      end
    end
  end
end

exporter = 'otel-collector' # console | otel-collector | jaeger-directly | zipkin-directly

if exporter == 'jaeger-directly'
  ## Jaeger config
  ENV['OTEL_TRACES_EXPORTER']= 'otlp'
  ENV['OTEL_EXPORTER_OTLP_ENDPOINT']="http://jaeger-docker-container:4318"
elsif exporter == 'otel-collector'
  ## OTLP config (Collector send data to GTempo of grafana, for example)
  ENV['OTEL_TRACES_EXPORTER']= 'otlp'
  ENV['OTEL_EXPORTER_OTLP_ENDPOINT']="http://otel-collector-docker-container:4318"
elsif exporter == 'zipkin-directly'
  #Zipkin config
  ENV['OTEL_TRACES_EXPORTER'] = 'zipkin'
  ENV['OTEL_EXPORTER_ZIPKIN_ENDPOINT']="http://zipkin-docker-container:9411"
elsif exporter == 'console'
  ENV['OTEL_TRACES_EXPORTER']= 'console'
end

require 'opentelemetry/sdk'
require 'opentelemetry-exporter-otlp'
require 'opentelemetry-exporter-zipkin'

OpenTelemetry::SDK.configure do |c|
  c.service_name = 'sinatra-app'
end

MySinatraTracer = OpenTelemetry.tracer_provider.tracer('my-sinatra-tracer-name-here')

def random_trace_id
  OpenTelemetry::Trace.generate_trace_id.unpack1('H*')
end

def generate_an_exception_for_trace
  begin
    1/0 # something that obviously fails
  rescue Exception => e
    current_span = OpenTelemetry::Trace.current_span
    current_span.status = OpenTelemetry::Trace::Status.error('Something went wrong!')
    current_span.record_exception(e, attributes: { 'exception_custom_attr' => 'some-value' })
  end
end

def random_sleep
  sleep((1..5).to_a.sample)
end

def random_boolean
  [false, true].sample
end

def make_request_to_rails_app
  url = URI.parse("http://rails_app:3000/my_route?x-trace-id=#{OpenTelemetry::Trace.current_span.context.hex_trace_id}")
  req = Net::HTTP::Get.new(url.to_s)
  res = Net::HTTP.start(url.host, url.port) {|http|
    http.request(req)
  }
  res.body
end

get '/my_route' do
  MySinatraTracer.in_span('Sinatra::/homepage', attributes: { 'my_custom_attribute' => 'my value' }) do |span|
    span.context.force_trace_id = [params['x-trace-id']].pack('H*') if params['x-trace-id'] && params['x-trace-id'] != ''

    span.add_attributes({ 'another_custom_attribute' => 'another-value', 'yet_another_attribute' => 'something' })

    random_sleep

    MySinatraTracer.in_span('Calculation of data', attributes: { 'calculation_attribute' => 'value-of-this' }) do |child_span|
      child_span.add_event('Starting calculation', attributes: { 'my_custom_parameter' => 'something' })
      random_sleep

      child_span.add_event('Finished calculated', attributes: { 'my_custom_result' => '1234.56' })
    end

    span.add_event("Rails app API call START")
    api_result = make_request_to_rails_app
    span.add_event("Rails app API call END", attributes: { "api_result" => api_result })

    generate_an_exception_for_trace if random_boolean

    separated_span = MySinatraTracer.start_span('Saving informations into database')
    separated_span.add_event('Connecting to database')
    random_sleep
    separated_span.add_event('Saved in database', attributes: { 'query_sql_used' => 'UPDATE mytable SET mycolumn = "something" WHERE id = 1234' })
    separated_span.finish

    "My route trace ID: #{OpenTelemetry::Trace.current_span.context.hex_trace_id}"
  end
end

get '/generate_random_trace_id' do
  random_trace_id
end
