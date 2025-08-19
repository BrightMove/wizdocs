#!/usr/bin/env ruby

require 'sinatra'

set :port, 3001
set :environment, 'development'

configure do
  enable :sessions
  set :session_secret, 'your-secret-key'
end

helpers do
  def number_with_delimiter(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end
end

before do
  puts "Request to #{request.path}"
end

get '/' do
  "Hello World! App is working."
end

get '/test' do
  "Test route working!"
end

if __FILE__ == $0
  puts "Test app starting on port 3001"
end
