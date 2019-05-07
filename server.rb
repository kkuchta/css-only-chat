require 'redis'
require 'json'
require 'securerandom'

# Since some requests (intentionally) never complete, ctrl-c won't kill this
# server.  Let's make sure it does.
Signal.trap(2) { exit }

# Misc redis keys
NEW_MESSAGE_CHANNEL = 'new_message_channel'.freeze
UPDATED_CLIENT_CHANNEL = 'updated_client_channel'.freeze
MESSAGE_LIST_KEY = 'message_list'.freeze

# Clear out any old messages when we boot up
Redis.new(url: ENV['REDIS_URL']).del(MESSAGE_LIST_KEY)

class Server
  def call(env)
    request = Rack::Request.new(env)

    response =
      case request.path
      when '/'
        index
      when '/style.css'
        style
      when %r{/img.*}
        image(request.path)
      when '/favicon.ico'
        [404, {}, []]
      end

    response || [500, {}, ['oops']]
  end

  private

  def redis
    @redis ||= Redis.new(url: ENV['REDIS_URL'])
  end

  def index
    # This endpoint streams forever.  IndexStreamer implements an `each` that
    # yields continuously (and blocks when there's nothing new to send)
    [200, {}, IndexStreamer.new]
  end

  def style
    [200, { 'Content-Type' => 'text/css'}, [File.read('style.css')]]
  end

  # Image names are `clientid_currentmessage_newbutton`, eg `bruce123_hellowor_l`
  def decode_image_name(image_name)
    client_id, current_message, new_letter = image_name.split('_')
    { client_id: client_id, current_message: current_message, new_letter: new_letter }
  end

  # Handle an image request.  We don't actually serv any images - it's just a
  # way for the client to send messages back to the server using the filename
  # of the requested image.
  def image(path)
    image_name = path.split('/').last
    button_press = decode_image_name(image_name)
    puts "Decoded button_press to #{button_press}"

    # `-` is our shorthand for a carriage return (needs to be a css-class-
    # friendly character)
    if button_press[:new_letter] == '-'
      new_message = {
        client_id: button_press[:client_id],
        body: button_press[:current_message].split('-').last,
        id: SecureRandom.uuid
      }

      # So we have a complete message now.  Save it in the list of messages.
      redis.lpush(MESSAGE_LIST_KEY, new_message.to_json)

      # Let all clients know there's a new message to display
      redis.publish(NEW_MESSAGE_CHANNEL, nil)

      # Let the sending client know to update it's displayed "current message"
      redis.publish(UPDATED_CLIENT_CHANNEL, {
        client_id: button_press[:client_id],
        new_string: button_press[:current_message] + button_press[:new_letter]
      }.to_json)
    else
      # Got a new letter press. Tell the sending client to display an updated
      # "current message."
      redis.publish(UPDATED_CLIENT_CHANNEL, {
        client_id: button_press[:client_id],
        new_string: button_press[:current_message] + button_press[:new_letter]
      }.to_json)
    end
    [200, {}, []]
  end
end

# A class whose "each" method blocks while waiting for messages from redis.  It
# yields new html to be streamed to a client and appended to the index.html
class IndexStreamer
  def redis
    @redis ||= Redis.new(url: ENV['REDIS_URL'])
  end

  def each(&each_block)
    # Generate a random name to differentiate clients  Duplicates will break
    # everything, but ¯\_(ツ)_/¯
    client_id = Faker::Name.first_name + rand(1000).to_s

    # Send the opening explanatory blurb and the initial onscreen keyboard.
    each_block.call(intro_html(client_id))
    each_block.call(keys_html('', client_id))

    # Need a new redis connection here, since you can't make any requests to
    # redis *after* a subscribe call on the same connection
    Redis
      .new(url: ENV['REDIS_URL'])
      .subscribe(NEW_MESSAGE_CHANNEL, UPDATED_CLIENT_CHANNEL) do |on|

      on.message do |channel, message|
        message = JSON.parse(message) unless message.empty?
        puts "#{client_id}: Just received message #{message} on channel #{channel}"

        case channel
        when NEW_MESSAGE_CHANNEL
          each_block.call(messages_html)
        when UPDATED_CLIENT_CHANNEL
          puts "#{client_id}: got UPDATED_CLIENT_CHANNEL"
          if message['client_id'] == client_id
            puts "#{client_id}: it's for me.  sending keys, #{message['new_string']}"
            each_block.call(keys_html(message['new_string'], client_id))
          end
        end
      end
    end

    # Should never really get here since the above stuff should block forever.
    puts "#{client_id}: post-subscribe block?!"
  end

  def encode_image_name(client_id:, current_message:, new_letter:)
    [client_id, current_message, new_letter].join('_')
  end

  def intro_html(client_id)
    "<html><head><link rel='stylesheet' href='style.css'/></head><body>" +
      "<h1>Welcome to CSS-only Chat!</h1>" +
      "<p>This page uses no javascript whatsosever - only CSS and html.  Blame @kkuchta for this.</p>" +
      "<p>Your name is #{client_id}.</p>"
  end

  # The html that displays the list of previous messages (up to 100 of them)
  def messages_html
    messages = redis.lrange(MESSAGE_LIST_KEY, 0, 100)
    puts "messages = #{messages}"

    list_html = messages.map do |message|
      message = JSON.parse(message)
      "<p><b>#{message['client_id']}:</b> #{message['body']}</p>"
    end.join

    last_message = JSON.parse(messages[0])['id']

    hide_previous_messages =
      if messages.count >= 2
        previous_last_message_id = JSON.parse(messages[1])['id']
        previous_last_message_class = "messages_#{previous_last_message_id}"
        "<style>.#{previous_last_message_class} { display: none; }</style>"
      end

    "<div class='messages messages_#{last_message}'>#{list_html}#{hide_previous_messages}</div>"
  end

  # The html that displays the keyboard keys.  The keys, when ':active' (the css
  # property of a button that's clicked), they'll get a background image assigned
  # to them, which will only
  def keys_html(previous_string, client_id)
    previous_previous_string = previous_string[0..-2]

    render_letter = ->(letter, label) {
      image_name = encode_image_name(
        client_id: client_id,
        current_message: previous_string,
        new_letter: letter
      )
      unique_class = 'insert_' + image_name
      result = "<button class='letter_#{letter} #{unique_class}'>#{label}</button>"
      result << "<style>.#{unique_class}:active { background-image: url('img/#{image_name}') }</style>"

      # hide previous generation
      unless previous_string == ''
        previous_unique_class = 'insert_' + encode_image_name(
          client_id: client_id,
          current_message: previous_previous_string,
          new_letter: letter
        )
        result << "<style>.#{previous_unique_class} { display: none; }</style>"
      end
      result
    }

    # Draw the keyboard
    letters = ('a'..'z').to_a.map do |letter|
      render_letter.call(letter, letter)
    end.join(' ') + render_letter.call('-', 'submit')

    clear_old_message = "<style>.message_#{previous_previous_string} { display: none }</style>"
    message_content = previous_string.end_with?('-') ? '' : previous_string.split('-').last
    message = "<div class='message_#{previous_string}'>Current Message: #{message_content || '...'}</div>"
    "<div class='keys'>#{letters + clear_old_message + message}</div>"
  end
end
