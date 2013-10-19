require 'rubygems'
require 'bundler/setup' 
require 'sinatra/base'
require 'sinatra/jsonp'
require_relative '../voteatx.rb'

module VoteATX

  class Service < Sinatra::Base   

    configure :development, :test do
      set :root, ENV['APP_ROOT'] || File.dirname(__FILE__) + "/../.."
    end

    # for :production, set :root in config.ru

    configure do
      $stderr.puts "Starting #{self.name} ..."
      $stderr.puts "CONFIGURE: environment = #{settings.environment}"
      $stderr.puts "CONFIGURE: root = #{settings.root}"

      set :public_folder, "#{settings.root}/public"
      $stderr.puts "CONFIGURE: public_folder = #{settings.public_folder}"

      database = "#{settings.root}/voteatx.db"
      $stderr.puts "CONFIGURE: database = #{database}"

      @@app = VoteATX::App.new(:database => database)
    end

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

    run! if app_file == $0

  end # Service
end # VoteATX
