bundler-api
===========

Environment
-----------

The follow environment variables are needed to run bundler-api. You can 
store these in the .gitignored ````.env```` file to have them automatically 
loaded by Foreman and ````script/setup````.

    RACK_ENV=development
    DATABASE_URL=postgres:///bundler-api
    FOLLOWER_DATABASE_URL=postgres:///bundler-api
    TEST_DATABASE_URL=postgres:///bundler-api-test


Databases
---------

  - `COBALT`: Master database.
  - `PURPLE`: Following `COBALT`. Read by public API to resolve dependencies.
  - `VIOLET`: Following `COBALT`. Read by `bundler-api-thin`,
    `bundler-api-jruby`, `bundler-api-puma`, `bundler-api-ruby2`, and
    [http://rubygems-org.herokuapp.com](http://rubygems-org.herokuapp.com)
