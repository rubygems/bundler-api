Sequel.migration do
  change do
    alter_table :rubygems do
      drop_column :deps_md5
    end
  end
end
