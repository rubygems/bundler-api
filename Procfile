web: bundle exec thin start -p $PORT -e $RACK_ENV
update: bundle exec rake continual_update[5,500]
pgstats: bundle exec rake collect_db_stats
