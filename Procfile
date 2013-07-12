web: bundle exec puma --include lib --port $PORT --environment $RACK_ENV --threads $MIN_THREADS:$MAX_THREADS
update: bundle exec rake continual_update[5,500]
