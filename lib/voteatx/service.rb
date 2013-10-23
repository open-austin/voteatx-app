require 'sinatra/base'
require 'sinatra/jsonp'
require 'logger'
require_relative '../voteatx.rb'

module VoteATX

  class Service < Sinatra::Base   

    # Initialization performed at service start-up.
    # 
    # Environment parameters to override configuration settings:
    #
    # APP_ROOT - Root directory of the application.
    # APP_DATABASE - Path to database file.
    # APP_DEBUG - If set, logging set to DEBUG level, which logs SQL operations.
    #
    configure do
      log = Logger.new($stderr)
      log.progname = self.name
      log_level = (ENV['APP_DEBUG'] ? "DEBUG" : "INFO")
      log.level = Logger.const_get(log_level)

      log.info "environment=#{settings.environment}"
      log.info "log level=#{log_level}"

      set :root, ENV['APP_ROOT'] || File.dirname(__FILE__) + "/../.."
      log.info "root=#{settings.root}"

      set :public_folder, "#{settings.root}/public"
      log.info "public_folder=#{settings.public_folder}"

      database = ENV['APP_DATABASE'] || "#{settings.root}/voteatx.db"
      log.info "database=#{database}"
      @@app = VoteATX::Finder.new(:database => database, :log => log)

      log.info "configuration complete"
    end


    # Helper methods for request handling.
    helpers Sinatra::Jsonp
    helpers do  

      def search(params)
        lat = nil
        lng = nil
        query_opts = {}

        params.each do |k, v|
          k = k.to_sym
          case k
          when :latitude
            lat = v.to_f
          when :longitude
            lng = v.to_f
          when :time, :max_distance, :max_locations
            query_opts[k] = v
          end
        end

        result = @@app.search(lat, lng, query_opts)

        content_type :json
        jsonp result.map{|e| e.to_h}
      end

    end


    before do
      @params = {}
      env = request.env
      @params.merge!(env['rack.request.form_hash']) unless env['rack.request.form_hash'].empty?
      @params.merge!(env['rack.request.query_hash']) unless env['rack.request.query_hash'].empty?
    end

       
    get '/' do
      redirect to('/index.html')
    end

    get '/svc/search' do
      search(@params)
    end

    post '/svc/search' do
      search(@params)
    end

    run! if app_file == $0

  end # Service
end # VoteATX
