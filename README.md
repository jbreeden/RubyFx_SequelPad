SequelPad
=========

Like LINQPad, but for Ruby &amp; [Sequel](http://sequel.jeremyevans.net/)

![screenshot](screenshot.png?raw=true)

Details
-------

Status: Alpha

This started as a simple demo of [rubyfx](https://github.com/jbreeden/rubyfx), but it turns out having a scratchpad for running Sequel queries is incredibly handy! SequelPad is currently alpha, at best, but it has already all but banished pgamdin from my desktop.

Essentially, SequelPad is just a Ruby code editor with Sequel preloaded and a table to display the results of your scripts. There are also a few added conveniences. For example, after connecting to a database and selecting a schema, `method_missing` will pick up any unrecognized identifiers in your script and interpret them as `db[:"schema__identifier"]`. If it cannot find an existing table in the selected schema by the exact name you provided, it will try again with case-insensitive matching. This makes scripts incredibly fast to write in SequelPad. Of course Sequel already makes database scripting incredibly fast and easy, so now is a good time to [get acquainted](http://sequel.jeremyevans.net/documentation.html) if you aren't already.

Plans
-----

Have I mentioned this is an alpha release? In fact, right now it only connect to postgres databases, though Sequel supports all of the major vendors. I also only haven't properly "gemified" the app yet, and I've just been running it with JRuby-Complete through a batch file (all included in the repo for now). Of course, if you have JRuby installed you can just checkout the repo and run bin/sequel-pad.rb to try it out.

As SequelPad has evolved from an afternoon project, to a weekend project, to my new favorite thing, my first steps will be to refactor the code and fit it into a test harness to ease the path forward. Afterwards, there is a growing list of features I intend to add, including support for other database vendors (which probably amounts to all of setting the connection strings correctly). I'll be tracking any new features through Github's issue tracker and I welcome any suggestions or contributors!
