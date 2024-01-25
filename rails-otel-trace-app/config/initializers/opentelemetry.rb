
ENV['OTEL_TRACES_EXPORTER']= 'console'

require 'opentelemetry/sdk'

OpenTelemetry::SDK.configure do |c|
  c.service_name = 'rails-app-service-name'
end

MyGlobalOpenTelemetryTracer = OpenTelemetry.tracer_provider.tracer('rails-app-trace-name')

=begin
1 Span pode ter varios attributos
1 Span pode ter varios events
1 event pode ter varios atributos
TRACE
  -> Span 1 (Span 1 can have attributes+events itself)
    -> Span 1.1 (Span 1.1 can have attributes itself)
    -> Span 1.2 (Span 1.2 can have attributes itself)
=end
