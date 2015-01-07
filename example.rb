#!/usr/bin/env ruby
require_relative 'jive_ruby_api' #This needs to point to the jive_ruby_api wherever it lives
config = {
  'username' => 'your_username', #If not passed, library looks for USER env var or prompts
  'password' => 'your_password', #If not passed, library looks for J_PASSWORD env var or prompts
  'debug' => false,
  'url' => 'https://url.com/api/core/v3' #Your jive instance url
  }

#Create new object with config hash
bs = Jive_ruby_api.new(config)

#get space api and html urls
puts bs.get_place("Services Reliability Engineering (SRE)", 'space')

#search query hash
search = {
  'search_string' => 'I love bananas', #Required
  'type' => 'document',                #Required
  'author' => 'your.name',             #Required defaults to config['username']
  'after' => '2014-12-11T00:00:000+0000' #Optional
}
#get content api and html urls
puts bs.find_content(search)

#doc = bs.find_content(search)[0]['api']
#puts doc

#create doc
#data hash
data = {
  'parent' => bs.get_place("Services Reliability Engineering (SRE)", 'space')[0]['api'],
  'text' => 'This is from the cli',
  'subject' => 'test post from cli',
  'type' => 'document'
}
puts bs.create_content(data)
