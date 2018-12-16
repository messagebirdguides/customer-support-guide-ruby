require 'dotenv'
require 'sinatra'
require 'messagebird'
require 'mongo'
require 'json'

set :root, File.dirname(__FILE__)

mongo_client = Mongo::Client.new('mongodb://localhost:27017/myproject')
DB = mongo_client.database

#  Load configuration from .env file
Dotenv.load if Sinatra::Base.development?

# Load and initialize MesageBird SDK
client = MessageBird::Client.new(ENV['MESSAGEBIRD_API_KEY'])

# Handle incoming webhooks
post '/webhook' do
  request.body.rewind
  request_payload = JSON.parse(request.body.read)

  # Read input sent from MessageBird
  number = request_payload['originator']
  text = request_payload['body']

  # Find ticket for number in our database
  tickets = DB[:tickets]
  doc = tickets.find(number: number).first

  if doc.nil?
    # Creating a new ticket
    doc = {
      number: number,
      open: true,
      messages: [
        {
          direction: 'in',
          content: text
        }
      ]
    }
    result = tickets.insert_one(doc)
    # After creating a new ticket, send a confirmation
    id_short = result.insertedId[18, 24]

    client.message_create(env['MESSAGEBIRD_ORIGINATOR'], [number], "Thanks for contacting customer support! Your ticket ID is #{id_short}.")
  else
    # Add an inbound message to the existing ticket
    doc["messages"].push({direction: 'in', content: text})
    tickets.update_one({ 'number' => number }, { '$set' => { 'open' => true, 'messages' => doc["messages"] } })
  end

  # Return any response, MessageBird won't parse this
  status 200
  body ''
end

get '/admin' do
  # Find all open tickets
  tickets = DB[:tickets]

  docs = tickets.find(open: true)

  # Shorten ID
  results = docs.each_with_object([]) do |doc, memo|
    memo.push({
      "shortId": doc["_id"].to_str[18, 24],
      "_id": doc["_id"],
      "number": doc["number"],
      "messages": doc["messages"]
    })
  end

  # Show a page with tickets
  return erb :admin, locals: { tickets: results }
end

post '/reply' do
  tickets = DB[:tickets]
  # Find existing ticket to reply to
  doc = tickets.find(_id: BSON::ObjectId.from_string(params['id'])).first

  unless doc.nil?
    # Add an outbound message to the existing ticket
    doc["messages"].push({direction: 'out', content: params['content']})

    tickets.update_one({ '_id' => BSON::ObjectId.from_string(params['id']) }, { '$set' => { 'open' => true, 'messages' => doc["messages"] } })

    # Send reply to customer
    client.message_create(ENV['MESSAGEBIRD_ORIGINATOR'], [doc["number"]], params['content'])
  end

  # Return to previous page
  redirect '/admin'
end
