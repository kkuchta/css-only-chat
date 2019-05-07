require 'rubygems'
require 'bundler'
require 'pry'

Bundler.require

# Loads a .env file to pick up your environment variables
require 'dotenv'
Dotenv.load

use Rack::Chunked

require './server'
run Server.new
