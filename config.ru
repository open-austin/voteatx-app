require 'rubygems'
require 'sinatra'
require './lib/voteatx'

root_dir = File.dirname(__FILE__)

set :environment, :production
set :root,  root_dir
#set :app_file, "#{root_dir}/lib/voteatx.rb"
disable :run
enable :logging

#log_dir = "../logs"
log_dir = "log"
log_file = "sinatra-#{Time.now.strftime("%Y%m%d")}.log"

FileUtils.mkdir_p(log_dir) unless Dir.exists?(log_dir)
log = File.new("#{log_dir}/#{log_file}", "a")
log.puts("=== Application restarted at " + Time.now.to_s)
$stdout.reopen(log)
$stderr.reopen(log)

run VoteATX::Service

