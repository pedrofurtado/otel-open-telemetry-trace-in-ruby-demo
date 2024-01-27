const express = require('express')
const app = express()
const port = 3000

const http = require('http')
const { NodeSDK } = require('@opentelemetry/sdk-node')
const { ConsoleSpanExporter } = require('@opentelemetry/sdk-trace-node')
const { Resource } = require('@opentelemetry/resources')
const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions')
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-proto')
const { ZipkinExporter } = require('@opentelemetry/exporter-zipkin')
const opentelemetry = require('@opentelemetry/api');
const tracer = opentelemetry.trace.getTracer('trace-node-app-name-here', '1.98.1')

const { execSync } = require('child_process')

function sleep(time) {
  return execSync('sleep ' + time)
}

process.env.OTEL_LOG_LEVEL = 'info'

let traceExporter = null
const exporter = 'otel-collector' //# console | otel-collector | jaeger-directly | zipkin-directly

if(exporter == 'jaeger-directly') {
  //## Jaeger config
  traceExporter = new OTLPTraceExporter({
    url: 'http://jaeger-docker-container:4318/v1/traces'
  })
}
else if(exporter == 'otel-collector') {
  //## OTLP config (Collector send data to GTempo of grafana, for example)
  traceExporter = new OTLPTraceExporter({
    url: 'http://otel-collector-docker-container:4318/v1/traces'
  })
}
else if(exporter == 'zipkin-directly') {
  //## Zipkin config
  traceExporter = new ZipkinExporter({
    url: "http://zipkin-docker-container:9411/api/v2/spans"
  })
}
else if(exporter == 'console') {
  traceExporter = new ConsoleSpanExporter()
}

const sdk = new NodeSDK({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: 'node-app',
    [SemanticResourceAttributes.SERVICE_VERSION]: '0.1.9'
  }),
  traceExporter: traceExporter
})

sdk.start()

function generateSpanException() {
  try {
    1 / 0
  } catch (ex) {
    const activeSpan = opentelemetry.trace.getActiveSpan()
    activeSpan.recordException(ex)
    activeSpan.setStatus({ code: opentelemetry.SpanStatusCode.ERROR })
  }
}

app.get('/my_route', (req, res) => {
  tracer.startActiveSpan('NodeApp::GET /my_route', { attributes: { node_route: 'value1' } }, (span) => {
    const x_trace_id = req.query['x-trace-id']
    if(x_trace_id && x_trace_id != '') { span.spanContext().traceId = x_trace_id }

    span.addEvent('Starting', { myAttrCustom: 'some-value' })
    sleep(5)

    span.addEvent('Middle', { myAttrCustom: 'some-value' })

    generateSpanException()

    tracer.startActiveSpan('NodeApp::DB query SQL', (childSpan) => {
      childSpan.addEvent('SELECT * FROM table', { results_from_db: 789 })
      childSpan.end()
    })

    tracer.startActiveSpan('NodeApp::Call sinatra app', (childSpan) => {
      http.get('http://sinatra_app:9292/my_route?x-trace-id=' + opentelemetry.trace.getActiveSpan().spanContext().traceId, http_res => {
        let data = []

        http_res.on('data', chunk => {
          data.push(chunk)
        })

        http_res.on('end', () => {
          const responseData = Buffer.concat(data).toString();
          console.log('Response ended: ' + responseData);

          childSpan.addEvent('Finished successfully sinatra REST API call', { api_result: responseData })
          childSpan.end()
          span.end()
          res.send("My route node! Trace ID " + opentelemetry.trace.getActiveSpan().spanContext().traceId)
        })
      })
    })
  })
})

app.listen(port, () => {
  console.log(`Example app listening on port ${port}`)
})
