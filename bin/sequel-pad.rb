require 'java'
require 'json'
require 'erb'
require_relative "../lib/sequel_pad"

# Developer Console
def reload
  Dir.glob("lib/**/*.rb").each { |file|
    load file
  }
end

Thread.new do
  require 'pry'
end

RubyFx.launch do |stage|
  $app = SequelPadController.new
  $app.fxml = "#{File.dirname __FILE__}/../lib/sequel_pad/views/sequel_pad.fxml"
  $app.stage = stage
  $app.start
end