require 'java'
require 'rubyfx'
require 'sequel'
require 'jdbc/postgres'
Jdbc::Postgres.load_driver

Dir.glob("#{File.dirname __FILE__}/sequel_pad/*.rb").each do |file|
  require file
end

Dir.glob("#{File.dirname __FILE__}/sequel_pad/controllers/*.rb").each do |controller|
  require controller
end