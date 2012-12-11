require 'metriks'

class PGStats
  def initialize(db, options = {})
    @db       = db
    @label    = options[:label]    || 'postgres'
    @counters = options[:counters] || Hash.new
    @interval = options[:interval] || 60
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
    stats.each do |name, current_counter|
      current_counter = current_counter.to_i
      last_counter    = @counters[name]
      if last_counter && current_counter >= last_counter
        value = current_counter - last_counter
        Metriks.histogram("#{@label}.#{name}").update(value)
      end
      @counters[name] = current_counter
    end
  end

end
