Vumi SMPP
=========

An SMPP transport connection for the Vumi project, in Ruby.

Install all the required stuff with [bundler][bundler].

    $ bundle install
    Using rake (0.8.7) 
    Using eventmachine (0.12.10) 
    Using amqp (0.6.7) 
    ... // snip // ...
    Using bundler (1.0.0.rc.6) 
    Your bundle is complete! Use `bundle show [gemname]` to see where a bundled gem is installed.
    
Run it with [rake][rake]:

    $ rake transport:start
    
By default it reads the `config.yaml` file. Specify the `config` command line argument to use a different file:

    $ rake transport:start config=custom.yaml

Notes
-----

* Only tested with Ruby version 1.9

[bundler]: http://gembundler.com
[rake]: http://rake.rubyforge.org/