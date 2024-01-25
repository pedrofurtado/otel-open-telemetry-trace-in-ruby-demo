Rails.application.routes.draw do
  get '/my_route' => 'application#my_route'
  get '/generate_random_trace_id' => 'application#generate_random_trace_id'
end
