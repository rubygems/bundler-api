Sequel.migration do
  change do
    alter_table :versions do
      add_column :yanked_at, DateTime, default: nil
    end
  end
end
