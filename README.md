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

  - `AMBER`: The primary database, set to `DATABASE_URL`. Writes from `web` and `update` processes go here. It is also the `FOLLOW_DATABASE_URL`, so reads come from it as well.
