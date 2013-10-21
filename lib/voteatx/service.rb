require 'sinatra/base'
require 'sinatra/jsonp'
require 'logger'
require_relative '../voteatx.rb'

module VoteATX

  class Service < Sinatra::Base   
    configure do
      @log = Logger.new($stderr)
      log_level = (ENV['APP_DEBUG'] ? "DEBUG" : "INFO")
      @log.level = Logger.const_get(log_level)

      @log.info "starting #{self.name}"
      @log.info "set environment #{settings.environment}"

      set :root, ENV['APP_ROOT'] || File.dirname(__FILE__) + "/../.."
      @log.info "set root #{settings.root}"

      set :public_folder, "#{settings.root}/public"
      @log.info "set public_folder #{settings.public_folder}"

      database = "#{settings.root}/voteatx.db"
      @log.info "set database #{database}"

      @log.info "set log level #{log_level}"
      @@app = VoteATX::Finder.new(:database => database, :log => @log)

      @log.info "initialization successful"
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
      send_result @@app.search(lat.to_f, lng.to_f, :time => @params[:time])
    end

    post '/svc/search' do
      lat = @params['latitude']
      lng = @params['longitude']
      send_result @@app.search(lat.to_f, lng.to_f, :time => @params[:time])
    end

    run! if app_file == $0

  end # Service
end # VoteATX
