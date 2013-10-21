require 'rubygems'
require 'bundler/setup' 

require 'cgi'
class String
  def escape_html
    CGI.escape_html(self)
  end
end

class NilClass
  def empty?
    true
  end
end

require_relative './voteatx/app.rb'
require_relative './voteatx/voting-place.rb'
