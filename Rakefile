require 'rdoc/task'

RDoc::Task.new do |rd|
  rd.title = "FindIt"
  rd.rdoc_dir = "rdoc/html"
  rd.main = "README.rdoc"
  ## rd.rdoc_files.include("**/*.rdoc", "bin/*", "lib/**/*.rb")
  rd.rdoc_files.include("**/*.rdoc", "lib/**/*.rb")
  ## rd.options = ""
end

namespace :rdoc do
  task :clean => [:clobber_rdoc]
  task :clobber => [:clobber_rdoc]
end
