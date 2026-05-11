require 'sinatra'
require 'sinatra/json'
require 'json'

set :port, ENV.fetch('PORT', 4567).to_i
set :bind, '0.0.0.0'

ITEMS = [
  { id: 1, name: 'Ruby Gem', description: 'A precious ruby gem' },
  { id: 2, name: 'Sinatra Song', description: 'My Way' }
]

get '/' do
  json({ message: 'Hello from Ruby Sinatra!', runtime: RUBY_VERSION, framework: 'Sinatra' })
end

get '/health' do
  json({ status: 'healthy', app: 'ruby-sinatra' })
end

get '/items' do
  json(ITEMS)
end

get '/items/:id' do
  item = ITEMS.find { |i| i[:id] == params[:id].to_i }
  halt 404, json({ error: 'Not found' }) unless item
  json(item)
end

post '/items' do
  request.body.rewind
  body = JSON.parse(request.body.read)
  item = { id: ITEMS.length + 1, name: body['name'], description: body['description'] || '' }
  ITEMS << item
  status 201
  json(item)
end
