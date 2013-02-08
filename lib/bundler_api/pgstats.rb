require 'librato/metrics'

class PGStats
  def initialize(db, options = {})
    @db       = db
    @label    = options[:label]    || 'postgres'
    @counters = options[:counters] || Hash.new
    @interval = options[:interval] || 60
    @client   = options[:client]   || Librato::Metrics.client
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

  def ratios
    @db[<<-SQL].first
      SELECT sum(idx_blks_hit) / sum(idx_blks_hit + idx_blks_read) AS cache_hit_ratio
      FROM pg_statio_user_indexes;
    SQL
  end

  def submit
    queue        = @client.new_queue
    measure_time = now_floored

    stats.each do |name, current_counter|
      current_counter = current_counter.to_i
      last_counter    = @counters[name]
      if last_counter && current_counter >= last_counter
        value = current_counter - last_counter
        queue.add("#{@label}.#{name}" => { :value        => value,
                                           :measure_time => measure_time })
      end

      @counters[name] = current_counter
    end

    ratios.each do |name, value|
      queue.add("#{@label}.#{name}" => { :value        => value,
                                         :measure_time => measure_time })
    end

    queue.submit unless queue.empty?
  end

  def now_floored
    time = Time.now.to_i
    time - (time % @interval)
  end
end
