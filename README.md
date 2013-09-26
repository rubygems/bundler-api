[![Code Climate](https://codeclimate.com/github/bundler/bundler-api.png)](https://codeclimate.com/github/bundler/bundler-api)
[![Build Status](https://travis-ci.org/bundler/bundler-api.png?branch=master)](https://travis-ci.org/bundler/bundler-api)

# bundler-api

## Getting Started

Run `script/setup` to create and migrate the database specified in the
`$DATABASE_URL` environment variable.

## Environment

The default environment is stored in `.env`. Override any of the settings
found there by creating a `.env.local` file.

## Production Databases

  - `COBALT`: Master database.
  - `PURPLE`: Following `COBALT`. Read by public API to resolve dependencies.
  - `VIOLET`: Following `COBALT`. Read by `bundler-api-thin`,
    `bundler-api-jruby`, `bundler-api-puma`, `bundler-api-ruby2`, and
    [http://rubygems-org.herokuapp.com](http://rubygems-org.herokuapp.com)
