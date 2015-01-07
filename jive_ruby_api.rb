#!/usr/bin/env ruby
#Script for updating updating jive
require 'json'

class Jive_ruby_api
  attr_accessor :username, :password, :debug, :url

  def initialize(config)
    @username = ENV['USER']
    @password = ENV['J_PASSWORD']
    @debug = false
    @url = 'https:/url.com/api/core/v3'

    if config.class != Hash
      STDERR.puts "Error: need hash to initialize. Found class: #{config.class}"
      exit 2
    end
    #Check options
    self.instance_variables.each do |v|
      v_stripped = v.to_s.sub(/@/, '')
      if self.instance_variable_get("#{v}").nil? && config["#{v_stripped}"].nil?
        #Will prompt if username or password is missing
        if "#{v}" == "@username" || "#{v}" == "@password"
          puts "WARN: #{v_stripped} not passed in or found from an environment variable"
          print "Enter #{v_stripped}: "
          v_input = gets.chomp
          build_config(v, v_input)
        end
      elsif ! config["#{v_stripped}"].nil?
        build_config(v, config["#{v_stripped}"])
      end
    end

    #Print debug information
    if  @debug == true
      puts "DEBUG: Values set to:"
      puts "  username => #{@username}"
      puts "  password => #{@password}"
      puts "  debug => #{@debug}"
      puts "  url => #{@url}"
    end

    @curl_get_prefix = "curl -s -u '#{@username}:#{@password}' -H 'Accept: application/json' -X GET "
    @curl_put_prefix = "curl -v -u '#{@username}:#{@password}' -H 'Content-Type: application/json' -H 'Expect:' -X PUT "
    @curl_post_prefix = "curl -s -u '#{@username}:#{@password}' -H 'Content-Type: application/json' -H 'Expect:' -X POST "
    #@curl_post_prefix = "curl --trace-ascii trace -u '#{@username}:#{@password}' -H 'Content-Type: application/json' -H 'Expect:' -X POST "
    #@curl_put_prefix = "curl --trace-ascii trace  -u '#{@username}:#{@password}' -H 'Content-Type: application/json' -H 'Expect:' -X PUT "
  end

  def build_config(config, value)
    case "#{config}"
    when "@username"
      @username ||= value
    when "@password"
      @password ||= value
    when "@debug"
      @debug = value
    when "@url"
      @url = value
    else
      STDERR.puts "config value #{config} not used!"
      exit 2
    end
  end



  #This strips the security string Jive implements with there GET requests
  def self.cleanse_security_string(security_string)
    return security_string.sub!("throw 'allowIllegalResourceCall is false.';", "")
  end

  #Get place by search query
  #Returns array of hashes like 
  #{"api"=>"https://url.com/api/core/v3/places/111111", "html"=>"https://url.com/blah/blah/place_name"}
  def get_place(search, type=nil)
    #check for spaces and html escape
    search.gsub!(/ /, "%20")

    type_filter = "&filter=type(#{type})" if ! type.nil?

    puts "get_place() #{@curl_get_prefix} '#{@url}/search/places?filter=search(#{search})#{type_filter}'" if @debug
    place_details = Jive_ruby_api.cleanse_security_string(`#{@curl_get_prefix} '#{@url}/search/places?filter=search(#{search})#{type_filter}'`)
    place_details = JSON.parse(place_details)
    array = Array.new
    place_details['list'].each do |result|
      array << { 'api' => result['resources']['self']['ref'], 'html' => result['resources']['html']['ref'] }
    end

    return array
    #return place_details['list'][0]['resources']['self']['ref']
    #This is just id -- return place_details['list'][0]['placeID']
  end

  #Get people id by username
  def get_username_id(username)
    #puts "#{@curl} -X GET '#{@url}/people/username/#{username}'" if @debug
    user_details = Jive_ruby_api.cleanse_security_string(`#{@curl_get_prefix} '#{@url}/people/username/#{username}'`)

    #Turn the string into a json object
    user_details = JSON.parse(user_details)
    return user_details['id']
  end

  #Find content with search query
  #Returns array of hashes like
  #{"api"=>"https://url.com/api/core/v3/contents/111111", "html"=>"https://url.com/docs/DOC-111111"}
  def find_content(search_parameters)
    #Expects hash with following keys
    #search_string
    #after
    #before
    #type
    #author
    if search_parameters.class != Hash || search_parameters['search_string'].nil?
      STDERR.puts "Error: find_content() requires Hash as argument"
      exit 2
    end
    #Required parameter
    search_string = "#{search_parameters['search_string']}"
    #check/replace for spaces in string
    search_string.gsub!(/ /, "%20")
    #Optional paramters
    author = get_username_id("#{search_parameters['author']}")
    author_filter = "&filter=author(/people/#{author})" unless author.nil?

    type_filter = "&filter=type(#{search_parameters['type']})" unless search_parameters['type'].nil?

    #Time is represented as 2014-12-11T00:00:000+0000
    after_filter = "&filter=after(#{search_parameters['after']})" unless search_parameters['after'].nil?
    before_filter = "&filter=before(#{search_parameters['before']})" unless search_parameters['before'].nil?

    puts "find_content() #{@curl_get_prefix} '#{@url}/search/contents/?filter=search(#{search_string})#{author_filter}#{type_filter}#{before_filter}#{after_filter}'" if @debug
    content_details = Jive_ruby_api.cleanse_security_string(`#{@curl_get_prefix} '#{@url}/search/contents/?filter=search(#{search_string})#{author_filter}#{type_filter}#{before_filter}#{after_filter}'`)
    content_details = JSON.parse(content_details)

    array = Array.new
    content_details['list'].each do |content|
      array << { 'api' => content['resources']['self']['ref'], 'html' => content['resources']['html']['ref'] }
    end
    return array

  end

  def get_time_string(created_on)
    time = DateTime.strptime("#{created_on}" '%Y-%m-%dT%H:%M:%S%Z')
    #time = DateTime.strptime("#{incident_hash['created_on']}" '%Y-%m-%dT%H:%M:%S%Z')
    time = time.strftime("%b %d, %Y at %H:%M:%S%p %Z")

    return time
  end

  #Retreive html from a ref path like https://url.com/api/core/v3/contents/111111
  def get_content(content_ref_path)
    puts " get_content() #{@curl_get_prefix} #{content_ref_path}" if @debug
    content_details = Jive_ruby_api.cleanse_security_string(`#{@curl_get_prefix} #{content_ref_path}`)
    content_details = JSON.parse(content_details)
    html_string = content_details['content']['text']

    return html_string

  end

  def create_content(data)
    #data should be a hash containing the following
    ##required##
    #text
    #subject
    #type
    ##optional##
    #parent
    #username
    #minor

    #Build data object
    data_object = {
      'content' => {
        'type' => 'text/html',
        'text' => data['text'],
      },
      'subject' => data['subject'],
      'parent' => data['parent'],
      'type' => data['type']
    }
    puts " create_content() #{@curl_put_prefix} -d #{data_object} '#{@url}/contents?minor=true" if @debug
    response = JSON.parse(`#{@curl_post_prefix} -d '#{data_object}' '#{@url}/contents?minor=true'`)

    #Return null or html ref
    return response['resources']['html']['ref']

  end

  def update_content(data)
    #data should be a hash containing the following
    #required
    #content_ref_path
    #text
    #optional
    #username
    #minor

  #def update_content(content_ref_path, text)
    puts "update_content() #{@curl_put_prefix} -d \"{ 'content': { 'type': 'text/html', 'text': '#{text}' }, 'subject': 'New Document', 'parent': '#{get_place('null')}', 'author': '#{get_username_id(@username)}' }\" '#{content_ref_path}?minor=true'" if @debug
    #text.gsub!(/\"/, "")
    #text.sub!(/\.<!--.*-->/, '')
    #puts text.inspect
    #puts "#{text}"
    #puts text.class
    #exit
    data = "{ 'content': { 'type': 'text/html', 'text': '" + text + "' }, 'subject': 'New Document', 'parent': '#{get_place('null')}', 'author': '#{get_username_id(@username)}' }"
    puts data
    exit
    `#{@curl_put_prefix}  -d "#{data}" "#{content_ref_path}?minor=true"`
    #`#{@curl_put_prefix} -d \"{ 'content': { 'type': 'text/html', 'text': '#{text}' }, 'subject': 'New Document', 'parent': '#{get_place('null')}', 'author': '#{get_username_id(@username)}' }\" '#{content_ref_path}?minor=true'`

  end

  private :build_config
end
