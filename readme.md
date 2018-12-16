# Building an SMS-Based Customer Support System with MessageBird

### ⏱ 30 min build time

## Why build SMS customer support?

In this MessageBird Developer Tutorial, we'll show you how to provide an excellent user experience by managing your inbound support tickets with this real-time SMS communication application between consumers and companies powered by the [MessageBird SMS Messaging API](https://developers.messagebird.com/docs/sms-messaging).

People love communicating in real time, regardless of whether it’s their friends or to a business. Real time support in a comfortable medium helps to create an excellent support experience that can contribute to retaining users for life.

On the business side, Support teams need to organize communication with their customers, often using ticket systems to combine all messages for specific cases in a shared view for support agents.

We'll walk you through the following steps:

* Customers can send any message to a virtual mobile number (VMN) created and published by the company. Their message becomes a support ticket, and they receive an automated confirmation with a ticket ID for their reference.
* Any subsequent message from the same number is added to the same support ticket; there's no additional confirmation.
* Support agents can view all messages in a web view and reply to them.

## Getting Started

Our sample application is built in Ruby using the [Sinatra framework](http://sinatrarb.com/). You can download or clone the complete source code from the [MessageBird Developer Tutorials GitHub repository](https://github.com/messagebirdguides/customer-support-guide-ruby) to run the application on your computer and follow along with the tutorial. To run the application, you will need [Ruby](https://www.ruby-lang.org/en/) and [bundler](https://bundler.io/) installed.

After saving the code, open a console for the download directory and run the following command which downloads the Sinatra framework, MessageBird SDK and other dependencies defined in the `Gemfile`:

```
bundle install
```

We use [MongoDB](https://rubygems.org/gems/mongo) to provide an in-memory database for testing, so you don't need to configure an external database.

## Prerequisites for Receiving Messages

### Overview

The support system receives incoming messages. From a high-level viewpoint, receiving with MessageBird is relatively simple: an application defines a _webhook URL_, which you assign to a number purchased in the MessageBird Dashboard using a flow. A [webhook](https://en.wikipedia.org/wiki/Webhook) is a URL on your site that doesn't render a page to users but is like an API endpoint that can be triggered by other servers. Every time someone sends a message to that number, MessageBird collects it and forwards it to the webhook URL where you can process it.

When working with webhooks, an external service like MessageBird needs to access your application, so the URL must be public. During development, though, you're typically working in a local development environment that is not publicly available. There are various tools and services available that allow you to quickly expose your development environment to the Internet by providing a tunnel from a public URL to your local machine. One of the most popular tools is [ngrok](https://ngrok.com/).

You can [download ngrok here for free](https://ngrok.com/download) as a single-file binary for almost every operating system, or optionally sign up for an account to access additional features.

You can start a tunnel by providing a local port number on which your application runs. We will run our Ruby server on port 4567, so you can launch your tunnel with this command:

```
ngrok http 4567
```

After you've launched the tunnel, ngrok displays your temporary public URL along with some other information. We'll need that URL in a minute.

Another common tool for tunneling your local machine is [localtunnel.me](https://localtunnel.me/), which you can have a look at if you're facing problems with ngrok. It works in virtually the same way but requires you to install [NPM](https://www.npmjs.com/) first.

### Getting an Inbound Number

A requirement for receiving messages is a dedicated inbound number. Virtual mobile numbers look and work in a similar way to regular mobile numbers, however, instead of being attached to a mobile device via a SIM card, they live in the cloud and can process incoming SMS and voice calls. MessageBird offers numbers from different countries for a low monthly fee; [feel free to explore our low-cost programmable and configurable numbers](https://www.messagebird.com/en/numbers).

Purchasing a number is quite easy:

Purchasing a number is quite easy:

1. Go to the '[Numbers](https://dashboard.messagebird.com/en/numbers)' section in the left-hand side of your Dashboard and click the blue button '[Buy a number](https://dashboard.messagebird.com/en/vmn/buy-number)' in the top-right side of your screen.
2. Pick the country in which you and your customers are located, and make sure both the SMS capability is selected.
3. Choose one number from the selection and the duration for which you want to pay now.
4. Confirm by clicking 'Buy Number' in the bottom-right of your screen.
![Buy a number](https://developers.messagebird.com/assets/images/screenshots/subscription-node/buy-a-number.png)

Awesome, you’ve set up your first virtual mobile number! 🎉

**Pro-Tip**: Check out our Help Center for more information about [virtual mobile numbers])https://support.messagebird.com/hc/en-us/sections/201958489-Virtual-Numbers and [country

### Connect Number to the Webhook

So you have a number now, but MessageBird has no idea what to do with it. That's why now you need to define a Flow that links your number to your webhook. This is how you do it:

#### STEP ONE
Go to [Flow Builder](https://dashboard.messagebird.com/en/flow-builder), choose the template ‘Call HTTP endpoint with SMS’ and click ‘Try this flow’.

![Call HTTP with SMS](https://developers.messagebird.com/assets/images/screenshots/support-node/call-HTTP-with-SMS.png)

#### STEP TWO
This template has two steps. Click on the first step ‘SMS’ and select the number or numbers you’d like to attach the flow to. Now, click on the second step ‘Forward to URL’ and choose `POST` as the method; copy the output from the ngrok command in the URL and add `/webhook` at the end—this is the name of the route we use to handle incoming messages in our sample application. Click on ‘Save’ when ready.

![Forward to URL](https://developers.messagebird.com/assets/images/screenshots/support-node/forward-to-URL.png)

#### STEP THREE
**Ready!** Hit ‘Publish’ on the right top of the screen to activate your flow. Well done, another step closer to building a customer support system for SMS-based communication!

![Support Receiver](https://developers.messagebird.com/assets/images/screenshots/support-node/support-receiver.png)

**Pro-Tip:** You can edit the name of the flow by clicking on the icon next to button ‘Back to Overview’ and pressing ‘Rename flow’.

![Rename Flow](https://developers.messagebird.com/assets/images/screenshots/support-node/rename-flow.png)

## Configuring the MessageBird SDK

The MessageBird SDK and an API key are not required to receive messages; however, since we want to send replies, we need to add and configure it. The SDK is defined in `Gemfile` and loaded with a statement in `app.rb`:

``` ruby
# Load and initialize MesageBird SDK
client = MessageBird::Client.new(ENV['MESSAGEBIRD_API_KEY'])
```

You need to provide a MessageBird API key, as well as the phone number you registered so that you can use it as the originator, via environment variables loaded with [dotenv](https://rubygems.org/gems/dotenv). We've prepared an env.example file in the repository, which you should rename to .env and add the required information. Here's an example:

```
MESSAGEBIRD_API_KEY=YOUR-API-KEY
MESSAGEBIRD_ORIGINATOR=+31970XXXXXXX
```

You can create or retrieve a live API key from the [API access (REST) tab](https://dashboard.messagebird.com/en/developers/access) in the [Developers section](https://dashboard.messagebird.com/en/developers/settings) of the MessageBird Dashboard.

## Receiving Messages

Now that the preparations for receiving messages are complete, we'll implement the `post '/webhook'` route:

```ruby
# Handle incoming webhooks
post '/webhook' do
  request.body.rewind
  request_payload = JSON.parse(request.body.read)

  # Read input sent from MessageBird
  number = request_payload['originator']
  text = request_payload['body']
```

MessageBird sends a few fields for incoming messages. We're interested in two of them: the `originator`, which is the number that the message came from (don't confuse it with the _originator_ you configured, which is for _outgoing_ messages), and the `body`, which is the content of the text message.

``` ruby
# Find ticket for number in our database
tickets = DB[:tickets]
doc = tickets.find(number: number).first
```

The number is used to look up the ticket; if none exists, we create a new ticket and add one inbound message to it:

```ruby
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
  result = collection.insert_one(doc)
```

As you can see, we store the whole message history in a single Mongo document using an array called `messages`. In the callback for the Mongo insert function we send the ticket confirmation to the user:

```ruby
# After creating a new ticket, send a confirmation
id_short = result.insertedId[18, 24]

client.message_create(env['MESSAGEBIRD_ORIGINATOR'], [number], "Thanks for contacting customer support! Your ticket ID is #{id_short}.")
```

Let's unpack this. First, we take an excerpt of the autogenerated MongoDB ID because the full ID is too long and the last 6 digits are unique enough for our purpose. Then, we call `client.message_create` to send a confirmation message. Three parameters are passed to the API:

* Our configured `originator`, so that the receiver sees a reply from the number which they contacted in the first place.
* A `recipient` array with the number from the incoming message so that the reply goes back to the right person.
* The `body` of the message, which contains the ticket ID.

So, what if a ticket already exists? In this case (our `else` block) we'll add a new message to the array and store the updated document; there’s no need to send another confirmation.

```ruby
else
  # Add an inbound message to the existing ticket
  doc.messages.push({direction: 'in', content: text})
  collection.update_one({ 'number' => number }, { '$set' => { 'open' => true, 'messages' => doc.messages } })
```


Servers sending webhooks typically expect you to return a response with a default 200 status code to indicate that their webhook request was received, but they don’t parse the response. Therefore, we send the string OK at the end of the route handler, regardless of the case that we handled.

```ruby
# Return any response, MessageBird won't parse this
status 200
body ''
```

## Reading Messages

Customer support team members can view incoming tickets from an admin view. We have implemented a simple admin view in the `get /admin` route. The approach is straightforward: request all documents representing open tickets from MongoDB, convert IDs as explained above and then pass them to an [ERB template](https://ruby-doc.org/stdlib-2.5.1/libdoc/erb/rdoc/ERB.html).

The template is stored in `views/admin.erb`. Apart from the HTML that renders the documents, there’s a small Javascript section in it that refreshes the page every 10 seconds; thanks to this, you can keep the page open and will receive messages automatically with only a small delay and without the implementation of Websockets.

This is the implementation of the route:

```ruby
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
```

## Replying to Messages

The admin template also contains a form for each ticket through which you can send replies. The implementation uses `client.message_create`, analogous to the confirmation messages we're sending for new tickets. If you're curious about the details, you can look at the `post /reply` implementation route in `app.rb`.

## Testing the Application

Double-check that you’ve set up your number correctly with a flow that forwards incoming messages to a ngrok URL and that the tunnel is still running. Keep in mind that whenever you start a fresh tunnel with the ngrok command, you'll get a new URL, so you have to update it in the flow accordingly.

To start the sample application you have to enter another command, but your existing console window is now busy running your tunnel, so you need to open another one. With Mac you can press **Command + Tab** to open a second tab that's already pointed to the correct directory. With other operating systems you may have to open another console window manually. Either way, once you've got a command prompt, type the following to start the application:

```
ruby app.rb
```

Open http://localhost:4567/admin in your browser. You should see an empty list of tickets. Then, take out your phone, launch the SMS app and send a message to your virtual mobile number; around 10-20 seconds later, you should see your message in the browser! Amazing! Try again with another message which will be added to the ticket, or send a reply.

Use the flow, code snippets and UI examples from this tutorial as an inspiration to build your own SMS Customer Support system. Don't forget to download the code from the [MessageBird Developer Tutorials GitHub repository](https://github.com/messagebirdguides/customer-support-guide-ruby).

**Nice work!** 🎉

You now have a running SMS Customer Support application!

## Start building!

Want to build something similar but not quite sure how to get started? Feel free to let us know at support@messagebird.com; we'd love to help!
