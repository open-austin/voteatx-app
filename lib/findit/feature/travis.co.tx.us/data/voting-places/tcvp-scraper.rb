require 'logger'
require 'mechanize'
require 'csv'

START_URL = "http://www.traviscountytax.org/displayEDSearch.do?vtype=d"

COLS = [
  :precinct,
  :name,
  :street,
  :city,
  :state,
  :zip,
  :geo_longitude,
  :geo_latitude,
  :geo_accuracy,
  :notes,
  # Leaving out directions. Use the Googles if you need it.
  ### :directions,
]

class String
  def capitalize_words
    self.split.map {|s| s.capitalize}.join(' ')
  end
end

@log = Logger.new($stderr)
@log.level = Logger::DEBUG

Mechanize.log = @log
@agent = Mechanize.new
### @agent.read_timeout = 60

page = @agent.get(START_URL)

form = page.form_with(:name => "pollingPlacesSubView:pollingPlacesForm")
selects = form.field_with(:name => "pollingPlacesSubView:pollingPlacesForm:pollingPlaceId")
submit = form.button_with(:name => "pollingPlacesSubView:pollingPlacesForm:submitButton")

puts COLS.to_csv

selects.options.each do |opt|
  
  selects.value = opt
  page2 = @agent.submit(form, submit)  
  form2 = page2.form_with(:name => "pollingPlaceMapSubView:pollingPlaceMapForm")
  
  precincts = form2["pollingPlaceMapSubView:pollingPlaceMapForm:precinct"].split(/[,\s]+/).map {|p| p.to_i}.sort
  
  place = {
    :precinct => nil, # will be filled out below
    ### :desc => form2["pollingPlaceMapSubView:pollingPlaceMapForm:desc"].strip,
    :geo_longitude => form2["pollingPlaceMapSubView:pollingPlaceMapForm:longitude"].to_f,
    :geo_latitude => form2["pollingPlaceMapSubView:pollingPlaceMapForm:latitude"].to_f,
    :geo_accuracy => "house",
    :notes => nil,
  } 
  
  t = page2.search(".//span[@class='mapData']")
  raise "failed to extract \"mapData\" elements" unless t && t.length == 2
  
  a = t[0].children.find_all {|n| n.type == Nokogiri::XML::Node::TEXT_NODE}
  raise "failed to parse first \"mapData\" element" unless a && a.length == 3
  place[:name], place[:street], citystatezip = a.map {|n| n.text.strip.capitalize_words}
    
  m = citystatezip.match(/^(.*), ([A-Z][a-z]) (.*)/)
  raise "failed to parse city/state/zip from \"#{m}\"" unless m && m.length == 4
  place[:city] = m[1]
  place[:state] = m[2].upcase
  place[:zip] = m[3].sub(/-0000$/, "")

  a = t[1].children.find_all {|n| n.type == Nokogiri::XML::Node::TEXT_NODE}
  place[:directions] = a.map {|s| s.text}.join(' ').strip.gsub(/\s+/,' ').capitalize
    
  if precincts.length > 1
    place[:notes] = "Combined precincts " + precincts.join(", ")
  end

  precincts.each do |pct|
    place[:precinct] = pct
    puts COLS.map {|k| place[k]}.to_csv
  end
    
end
