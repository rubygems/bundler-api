Sequel.migration do
  change do
    alter_table :versions do
      add_column :yanked_info_checksum, String, size: 255, default: nil
    end
  end
end
