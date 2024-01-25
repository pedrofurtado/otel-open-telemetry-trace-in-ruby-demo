class ApplicationController < ActionController::Base
  def generate_random_trace_id
    render plain: OpenTelemetry::Trace.generate_trace_id.unpack1('H*')
  end

  def my_route
    # os attributes precisam ser passados exatamente dessa forma (chave e valor como string):
    # { "chave" => "valor" }
    # nao pode passar assim, senao da erro:
    # { chave: "valor" }
    # { :'chave' => "valor" }
    # { :chave => "valor" }
    # When you use "in_span do ... end", the span is automatically finished.
    # When you use "start_span()", you need to explicitly call "finish()" at the end.
    MyGlobalOpenTelemetryTracer.in_span('ApplicationController::my_example_route', attributes: { 'my_custom_attribute' => 'my value' }) do |span|
      # Force trace_id to not be automatically generated, but use from headers/query-string/so on. It is important for distributed tracing that contains same ID between app-to-app calls.
      span.context.force_trace_id = [params['x-trace-id']].pack('H*') if params['x-trace-id'].present?

      span.add_attributes({ 'another_custom_attribute' => 'another-value', 'yet_another_attribute' => 'something' })

      random_sleep

      MyGlobalOpenTelemetryTracer.in_span('Calculation of data', attributes: { 'calculation_attribute' => 'value-of-this' }) do |child_span|
        child_span.add_event('Starting calculation', attributes: { 'my_custom_parameter' => 'something' })
        random_sleep

        child_span.add_event('Finished calculated', attributes: { 'my_custom_result' => '1234.56' })
      end

      generate_an_exception_for_trace if random_boolean

      separated_span = MyGlobalOpenTelemetryTracer.start_span('Saving informations into database')
      separated_span.add_event('Connecting to database')
      random_sleep
      separated_span.add_event('Saved in database', attributes: { 'query_sql_used' => 'UPDATE mytable SET mycolumn = "something" WHERE id = 1234' })
      separated_span.finish

      render plain: "My route trace ID: #{OpenTelemetry::Trace.current_span.context.hex_trace_id}"
    end
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
end
