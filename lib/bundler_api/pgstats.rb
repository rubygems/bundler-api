require_relative 'metriks'

class PGStats
  def self.collect_from_db(db)
    dataset = db[<<-SQL]
      SELECT sum(seq_scan)  AS sequence_scans,
             sum(idx_scan)  AS index_scans,
             sum(n_tup_ins) AS inserts,
             sum(n_tup_upd) AS updates,
             sum(n_tup_del) AS deletes
      FROM pg_stat_user_tables;
    SQL

    dataset.each do |row|
      row.each do |name, value|
        Metriks.meter("postgres.#{name}").update(value.to_i)
      end
    end
  end
end

# Replace monkeypatch with metriks-derive.
class Metriks::Meter
  def update(total)
    if count == 0
      @count.value = total
    else
      mark(total - count)
    end
  end
end
