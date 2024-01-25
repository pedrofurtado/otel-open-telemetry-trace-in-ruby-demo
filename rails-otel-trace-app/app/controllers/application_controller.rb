class ApplicationController < ActionController::Base
  def my_example_route
    MyGlobalOpenTelemetryTracer.in_span('exemplo') do |span|
      span.add_attributes({
        "meu-atributo" => 'legal',
        "meu-valor" => 'teste'
      })
      MyGlobalOpenTelemetryTracer.in_span('exemplo-filho') do |child_span|
        # ao usar "in_span do ... end", o span e automaticamente fechado.
        child_span.add_event('evento1-do-filho')
      end

      generate_an_exception_for_trace

      outro_span = MyGlobalOpenTelemetryTracer.start_span('outro-exemplo-avulso')
      outro_span.add_event('evento-do-spam-avulso')
      outro_span.add_event('evento-do-spam-avulso-com-atributos', attributes: { attr1: 'bla', attr2: 'ble', attr3: 'bli' })
      outro_span.finish

      render plain: 'My example route!'
    end
  end

  def generate_an_exception_for_trace
    begin
      1/0 # something that obviously fails
    rescue Exception => e
      current_span = OpenTelemetry::Trace.current_span
      current_span.status = OpenTelemetry::Trace::Status.error("error message here!")
      current_span.record_exception(e, attributes: { attr1: 'valor-qualquer' })
    end
  end
end
