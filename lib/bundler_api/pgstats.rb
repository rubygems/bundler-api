require 'librato/metrics'
require_relative 'metriks'

class PGStats
  def initialize(db, client = Librato::Metrics.client)
    @db       = db
    @client   = client
    @counters = Hash.new
  end

  def stats
    @db[<<-SQL].first
      SELECT sum(seq_scan)  AS sequence_scans,
             sum(idx_scan)  AS index_scans,
             sum(n_tup_ins) AS inserts,
             sum(n_tup_upd) AS updates,
             sum(n_tup_del) AS deletes
      FROM pg_stat_user_tables;
    SQL
  end

  def submit
    queue = @client.new_queue

    stats.each do |name, current_counter|
      current_counter = current_counter.to_f
      last_counter    = @counters[name]
      if last_counter && current_counter >= last_counter
        value = current_counter - last_counter
        p("postgres.#{name}" => value)
        queue.add("postgres.#{name}" => value)
      end

      @counters[name] = current_counter
    end

    queue.submit unless queue.empty?
  end
end
