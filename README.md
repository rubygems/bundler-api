bundler-api
===========

Environment
-----------

The follow environment variables are needed to run bundler-api.

```
RACK_ENV=development
DATABASE_URL=postgres:///bundler-api
FOLLOWER_DATABASE_URL=postgres:///bundler-api
TEST_DATABASE_URL=postgres:///bundler-api-test
```

Databases
---------

 - `COBALT`: Master database.
 - `TEAL`: Following `COBALT`. Read by public API to resolve dependencies.
 - `ONYX`: Following `COBALT`. Read by
   [http://rubygems-org.herokuapp.com](http://rubygems-org.herokuapp.com)
   to create a gem source.
