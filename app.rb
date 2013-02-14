# -*- coding: utf-8 -*-
require 'digest/md5'
require 'csv'
require 'haml'
require 'open-uri'
require 'gdata'
require 'rack-flash'

require 'openid/extensions/sreg'
OpenID::SReg::DATA_FIELDS["charname"] = "Character Name"

module Nesta
  class App
    helpers do
			# Define your own helper methods here.

			def extract_charname(resp)
				sreg = OpenID::SReg::Response.from_success_response(resp)
				return sreg['charname']
			end

			def require_authentication
				if resp = request.env["rack.openid.response"]
					yield resp
				else
					headers 'WWW-Authenticate' => Rack::OpenID.build_header(:identifier => "http://skyrates.net/OpenID/", :required => ["charname"])
					throw :halt, [401, 'got openid?']
				end
			end

			def require_successful_authentication
				session = env['rack.session']
				require_authentication do |resp|
					if resp.status == :success
						name = extract_charname(resp)
						session[:names] = (session[:names].to_a + [name]).uniq
						yield name
					else
						"Error: #{resp.inspect}"
					end
				end
			end

			def authenticated_as
				session = env['rack.session']
				if session[:name]
					yield session[:name]
				else
					require_successful_authentication do |name|
						session[:name] = name
						yield name
					end
				end
			end

		end
	  enable :inline_templates
	  enable :sessions
	  use Rack::Flash

	  ["/skyrates/gravatar/:default/:rating/:name", "/skyrates/gravatar/:name"].each do |path|
			get path do
				response["Cache-Control"] = "max-age=3000, public"
				CSV.parse(URI.parse("https://spreadsheets.google.com/pub?key=0Av1Kj9U6OXGSdE9sTW5uOXlzU1BsMU5MM25kck9rREE&authkey=CJrync0F&single=true&gid=0&output=csv").read) do |row|
					if row[0] === params[:name] then
						email = row[1].strip.downcase
						d = params[:default] || "404"
						r = params[:rating] || "pg"
						redirect "http://www.gravatar.com/avatar/#{Digest::MD5.hexdigest(email)}?d=#{d}&r=#{r}&s=80", 307
						break
					end
				end
				throw :halt, [404, "Not here"]
			end
		end

	  get '/skyrates/halfmoderate/logout' do
			session = env['rack.session']
			session[:name] = nil
			session[:names] = nil
			haml :halfmoderate_logout
		end

	  get '/skyrates/halfmoderate/login' do
			require_successful_authentication do |name|
				env['rack.session'][:name] = name
				@name = name
				flash[:notice] = "You have logged in as #{name}."
				redirect "/skyrates/halfmoderate"
			end
		end

	  get '/skyrates/halfmoderate/switch/:name' do
			session = env['rack.session']
			name = params[:name]
			if session[:names].to_a.include? name
				session[:name] = name
				flash[:notice] = "You have switched to #{name}"
			else
				flash[:notice] = "You haven't ever logged in with that character."
			end
			redirect "/skyrates/halfmoderate"
		end

	  get '/skyrates/halfmoderate' do
			authenticated_as do |name|
				@name = name
				@names = env['rack.session'][:names].to_a
				client = GData::Client::Spreadsheets.new
				client.clientlogin(ENV['GS_LOGIN'], ENV['GS_PASSWORD'])
				feed = client.get('https://spreadsheets.google.com/feeds/list/0Av1Kj9U6OXGSdC1DRXdGeUZQbDRGZDJoSUVGMGFUV3c/1/private/full').to_xml
				entry = feed.elements["entry[gsx:name='#{@name}']"]
				@image = entry ? entry.elements['gsx:avatar'].text : nil
				haml :halfmoderate
			end
		end


	  post '/skyrates/halfmoderate' do
			avatar = params[:image]
			authenticated_as do |name|
				client = GData::Client::Spreadsheets.new
				client.clientlogin(ENV['GS_LOGIN'], ENV['GS_PASSWORD'])
				feed = client.get('https://spreadsheets.google.com/feeds/list/0Av1Kj9U6OXGSdC1DRXdGeUZQbDRGZDJoSUVGMGFUV3c/1/private/full').to_xml
				entry = feed.elements["entry[gsx:name='#{name}']"]
				if entry
					entry.elements['gsx:avatar'].text = avatar
					entry.add_namespace('http://www.w3.org/2005/Atom')
					entry.add_namespace('gd','http://schemas.google.com/g/2005')
					entry.add_namespace('gsx','http://schemas.google.com/spreadsheets/2006/extended')
					client.put(entry.elements["link[@rel='edit']"].attributes['href'], entry.to_s)
				else
					entry = "<entry xmlns='http://www.w3.org/2005/Atom'
					xmlns:gsx='http://schemas.google.com/spreadsheets/2006/extended'>
						<gsx:name>#{name}</gsx:name>
						<gsx:avatar>#{avatar}</gsx:avatar>
					</entry>"
					client.post(feed.elements["link[@rel='http://schemas.google.com/g/2005#post']"].attributes["href"], entry)
				end
			end
			redirect '/skyrates/halfmoderate'
		end

		get '/resume.pdf' do
			redirect 'http://dl.dropbox.com/u/7303416/resume.pdf', 307
		end

		get '/cv.pdf' do
			redirect 'http://dl.dropbox.com/u/7303416/cv.pdf', 307
		end

  end
end

__END__

@@ halfmoderate
%div{:style => "float:right" }
	%p
		%a{:href => "/skyrates/halfmoderate/logout"}
			Log out
- if @image
	%img{ :src => "#{@image}" }
%p
	Hey #{@name}!
	- if @image
		You are currently using this avatar on Half-moderated Avatars.
	- else
		You are not currently using an avatar on Half-moderated Avatars.
%p
	:markdown
		To set the avatar for an alt, switch pilot on [Skyrates](http://skyrates.net/character.php),
		then [force a new login](/skyrates/halfmoderate/login).
%form{ :action => '/skyrates/halfmoderate', :method => 'post' }
	%input{ :type => 'text', :id => 'image', :name => 'image', :value => "#{@image}" }
	%input{ :type => 'submit', :value => "Set your avatar" }

@@ halfmoderate_logout
%p You have logged out.
