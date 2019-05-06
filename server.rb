require 'redis'
require 'json'

NEW_MESSAGE_CHANNEL='new_message_channel'
UPDATED_CLIENT_CHANNEL='updated_client_channel'
MESSAGE_LIST_KEY='message_list'
ISO8601='%Y-%m-%dT%H:%M:%S.%L%z'

class Server
  def call(env)
    @@redis ||= Redis.new(url: ENV['REDIS_URL'])
    request = Rack::Request.new(env)

    response = case request.path
    when '/'
      index
    when '/style.css'
      style
    when %r(/img.*)
      image_name = request.path.split('/').last
      button_press = decode_image_name(image_name)
      puts "Decoded button_press to #{button_press}"

      # - is our shorthand for a carriage return for now
      if button_press[:new_letter] == '-'
        new_message = {
          client_id: button_press[:client_id],
          body: button_press[:current_message]
        }
        @@redis.lpush(MESSAGE_LIST_KEY, new_message)
        @@redis.publish(NEW_MESSAGE_CHANNEL, '')
      else
        puts "Publishing on UPDATED_CLIENT_CHANNEL"
        @@redis.publish(UPDATED_CLIENT_CHANNEL, {
          client_id: button_press[:client_id],
          new_string: button_press[:current_message] + button_press[:new_letter]
        }.to_json)
      end
      [200, {}, []]
    when '/favicon.ico'
      [404, {}, []]
    end

    return response || [500, {}, ['oops']]
  end

  def index
    [200, {}, IndexStreamer.new]
  end

  # Image names are `clientid_currentmessage_newbutton`
  def decode_image_name(image_name)
    client_id, current_message, new_letter = image_name.split('_')
    { client_id: client_id, current_message: current_message, new_letter: new_letter }
  end

  # Messages should look like { client_id: 123, body: "hey!", send_at: iso8601 }
  # returns a string to be published as html to the *current thread's* client.
  def handle_message(message)
    id = message.client_id
  end

  def style
    [200, { 'Content-Type' => 'text/css'}, [File.read('style.css')]]
  end
end

class IndexStreamer
  def each(&each_block)
    @@redis ||= Redis.new(url: ENV['REDIS_URL'])

    client_id = Faker::Name.first_name + rand(1000).to_s

    each_block.call(keys_html('', client_id))

    puts "subscribing"

    @@redis.subscribe(UPDATED_CLIENT_CHANNEL) do |on|
      on.message do |channel, message|
        message = JSON.parse(message)
        puts "Just received message #{message} on channel #{channel}"
        case channel
        when NEW_MESSAGE_CHANNEL
          # ... TODO
        when UPDATED_CLIENT_CHANNEL
          puts "clientid = #{client_id}"
          puts "message clientid = #{message['client_id']}"
          if message['client_id'] == client_id
            each_block.call(keys_html(message['new_string'], client_id))
          end
        end
      end
    end
  end

  def encode_image_name(client_id:, current_message:, new_letter:)
    [client_id, current_message, new_letter].join('_')
  end

  def keys_html(previous_string, client_id)
    previous_previous_string = previous_string[0..-2]
    letters = (('a'..'z').to_a + ['-']).map do |letter|
      image_name = encode_image_name(client_id: client_id, current_message: previous_string, new_letter: letter)
      unique_class = 'insert_' + image_name
      result = "<button class='letter_#{letter} #{unique_class}'>#{letter}</button>"
      result << "<style>.#{unique_class}:active { background-image: url('img/#{image_name}') }</style>"

      # hide previous generation
      unless previous_string == ''
        previous_unique_class = 'insert_' + encode_image_name(client_id: client_id, current_message: previous_previous_string, new_letter: letter)
        result << "<style>.#{previous_unique_class} { display: none; }</style>"
      end
      result
    end.join(' ')

    clear_old_message = "<style>.message_#{previous_previous_string} { display: none }</style>"
    message = "<div class='message_#{previous_string}'>Message=#{previous_string}</div>"
    letters + clear_old_message + message
  end
end
