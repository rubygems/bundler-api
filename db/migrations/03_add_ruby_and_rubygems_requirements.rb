Sequel.migration do
  up do
    alter_table :versions do
      add_column :rubygems_version, String, :size=>255
      add_column :required_ruby_version, String, :size=>255
    end
  end

  down do
    alter_table :versions do
      drop_column :rubygems_version
      drop_column :required_ruby_version
    end
  end
end
