require 'rubygems'
require 'rake'
require 'echoe'

Echoe.new('ruby-dzi', '0.1.2') do |p|
  p.description    = "Ruby Dzi slices images into several tiles and creates dzi descriptor file."
  p.url            = "http://github.com/panter/ruby-dzi"
  p.author         = "Panter llc"
  p.ignore_pattern = ["*.jpg", "*_files/**/**", "test.rb", "*.dzi", "pkg/*", "pkg/**/**"]
  p.development_dependencies = ["rmagick"]
end

Dir["#{File.dirname(__FILE__)}/tasks/*.rake"].sort.each { |ext| load ext }

