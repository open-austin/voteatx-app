require 'sinatra/base'
require 'sinatra/jsonp'
require 'logger'
require_relative '../voteatx.rb'

module VoteATX

  class Service < Sinatra::Base   

    # Initialization performed at service start-up.
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
      @params.merge!(request.env['rack.request.form_hash'] || {})
      @params.merge!(request.env['rack.request.query_hash'] || {})
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
