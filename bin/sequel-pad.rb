require 'java'
require 'json'
require 'erb'
require_relative "../lib/sequel_pad"

# Allows hot-loading of files for quick testing & development
def reload
  Dir.glob("lib/**/*.rb").each { |file|
    load file
  }
end

# Running pry in the background for exploratory programming
Thread.new do
  require 'pry'
end

RubyFx.launch do |stage|
  $app = SequelPadController.new
  $app.fxml = "#{File.dirname __FILE__}/../lib/sequel_pad/views/sequel_pad.fxml"
  $app.stage = stage
  $app.start
end
