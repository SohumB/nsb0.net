require 'rubygems'
require 'bundler/setup'

Bundler.require(:default)

use Rack::Session::Cookie
require "rack/openid"
require 'openid/store/memcache'
require 'dalli'
load "dalli-adapter.rb"

use Rack::OpenID, ::OpenID::Store::Memcache.new(DalliAdapter.new(Dalli::Client.new))

require 'nesta/app'

Nesta::App.root = ::File.expand_path('.', ::File.dirname(__FILE__))
run Nesta::App
