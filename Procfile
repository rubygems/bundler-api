web: bundle exec puma -p $PORT -e $RACK_ENV -t $MIN_THREADS:$MAX_THREADS
update: bundle exec rake continual_update[5,500]
pgstats: bundle exec rake collect_db_stats
