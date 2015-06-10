Sequel.migration do
  change do
    alter_table :versions do
      add_column :created_at, DateTime
    end
  end
end
