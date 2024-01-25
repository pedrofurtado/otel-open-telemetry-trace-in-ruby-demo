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


## Jaeger config
ENV['OTEL_TRACES_EXPORTER']= 'otlp' # console | otlp | zipkin
ENV['OTEL_EXPORTER_OTLP_ENDPOINT']="http://jaeger-docker-container:4318"

require 'opentelemetry/sdk'
require 'opentelemetry-exporter-otlp'

OpenTelemetry::SDK.configure do |c|
  c.service_name = 'rails-app'
end

MyGlobalOpenTelemetryTracer = OpenTelemetry.tracer_provider.tracer('my-tracer-name-here')

=begin
1 Span pode ter varios attributos
1 Span pode ter varios events
1 event pode ter varios atributos
TRACE
  -> Span 1 (Span 1 can have attributes+events itself)
    -> Span 1.1 (Span 1.1 can have attributes itself)
    -> Span 1.2 (Span 1.2 can have attributes itself)
=end
