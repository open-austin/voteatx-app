require 'rubygems'
require 'bundler/setup' 
require 'sinatra/base'
require 'sinatra/jsonp'

module VoteATX
  BASEDIR = File.dirname(__FILE__) + '/..'
end

require_relative './voteatx/app.rb'

module VoteATX

  class Service < Sinatra::Base   

    @@app = VoteATX::App.new

    set :public_folder, BASEDIR + '/public'

    helpers do  
      helpers Sinatra::Jsonp
      def send_result(result)
        content_type :json
        jsonp result.map{|e| e.to_h}
      end
    end

    before do
      @params = {}
      @params.merge!(request.env['rack.request.form_hash'] || {})
      @params.merge!(request.env['rack.request.query_hash'] || {})
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
      lat = @params['latitude']
      lng = @params['longitude']
      send_result @@app.search(lat.to_f, lng.to_f)
    end

  end # Service
end # VoteATX
