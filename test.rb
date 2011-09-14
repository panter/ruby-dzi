require 'lib/ruby_dzi'
dzi = RubyDzi.new('coffee.jpg')
puts dzi.image_path

dzi.generate!('coffee')

