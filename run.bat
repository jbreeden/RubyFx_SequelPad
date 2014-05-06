set GEM_HOME=gems
java -XX:+TieredCompilation -XX:TieredStopAtLevel=1 -Xms50m -Xmx70m -cp "jars/*;." org.jruby.Main bin/sequel-pad.rb
