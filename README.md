bundler-api
===========

Databases
---------

 - `COBALT`: Master database.
 - `TEAL`: Following `COBALT`. Read by public API to resolve dependencies.
 - `ONYX`: Following `COBALT`. Read by
   [http://rubygems-org.herokuapp.com](http://rubygems-org.herokuapp.com)
   to create a gem source.
