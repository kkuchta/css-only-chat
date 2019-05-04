class Server
  def call(env)
    request = Rack::Request.new(env)

    response = case request.path
    when '/'
      index
    when '/style.css'
      style
    when %r(/img.*)
      string = request.path.split('/').last
      @global_response_enumerator.feed keys_html(string)
      [200, {}, []]
    when '/favicon.ico'
      [404, {}, []]
    end

    return response || [500, {}, ['oops']]
  end

  def index
    response = Object.new
    @global_response_enumerator ||= ResponseEnumerator.new
    @global_response_enumerator.feed ("<html>\n")
    @global_response_enumerator.feed (keys_html('') + "\n")
    #@global_response_enumerator.feed "<img src='img/1' />"
    #@global_response_enumerator.feed(keys_html('') + "\n")
    #def response.each
      #yield "<html>\n"
      #yield keys_html('') + "\n"
      #yield "</html>\n"
    #end
    [200, {}, @global_response_enumerator]
  end

  def keys_html(previous_string)
    previous_previous_string = previous_string[0..-2]
    letters = ('a'..'z').map do |letter|
      last_string_plus_letter = previous_previous_string + letter
      unique_class = 'insert_' + previous_string + letter
      result = "<button class='letter_#{letter} #{unique_class}'>#{letter}</button>"
      result << "<style>.#{unique_class}:active { background-image: url('img/#{previous_string + letter}') }</style>"

      # hide previous generation
      unless previous_string == ''
        result << "<style>.insert_#{last_string_plus_letter} { display: none; }</style>"
      end
      result
    end.join(' ')

    clear_old_message = "<style>.message_#{previous_previous_string} { display: none }</style>"
    message = "<div class='message_#{previous_string}'>Message=#{previous_string}</div>"
    letters + clear_old_message + message
  end
  def style
    [200, { 'Content-Type' => 'text/css'}, [File.read('style.css')]]
  end
end

class ResponseEnumerator
  def initialize
    @content = []
  end
  def feed(x)
    @content << x
  end
  def each
    loop do
      if @content.empty?
        sleep 1
      else
        yield @content.shift
      end
    end
  end
end
