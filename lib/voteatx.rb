require 'rubygems'
require 'bundler/setup' 

require 'sinatra/base'
require 'sinatra/jsonp'
require 'uri'
require 'json'

require_relative './voteatx/app.rb'


module VoteATX
  class Service < Sinatra::Base   

    @@app = VoteATX::App.new

    BASEDIR = File.dirname(__FILE__) + '/..'

    set :public_folder, BASEDIR + '/public'

    helpers do  
      helpers Sinatra::Jsonp
      def send_result(result)
        content_type :json
        jsonp result.map{|e| e.to_h}
      end
    end

    before do
      @params = request.env['rack.request.query_hash']
    end
       
    get '/' do
      redirect to('/index.html')
    end

    get '/svc/search' do
      lat = @params['latitude']
      lng = @params['longitude']
      send_result @@app.search(lat.to_f, lng.to_f)
    end

    post '/svc/search' do
      a = URI.decode_www_form(request.body.read)
      lat = (a.assoc('latitude') || []).last
      lng = (a.assoc('longitude') || []).last
      send_result @@app.search(lat.to_f, lng.to_f)
    end

  end # Service
end # VoteATX
