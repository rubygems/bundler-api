Sequel.migration do
  up do
    drop_table :linksets

    alter_table :dependencies do
      drop_column :created_at
      drop_column :updated_at
      drop_column :unresolved_name
    end

    alter_table :rubygems do
      drop_column :created_at
      drop_column :updated_at
      drop_column :downloads
      drop_column :slug
    end

    alter_table :versions do
      drop_column :created_at
      drop_column :updated_at
      drop_column :authors
      drop_column :description
      drop_column :built_at
      drop_column :rubyforge_project
      drop_column :position
      drop_column :latest
    end
  end

  down do
    create_table(:linksets, :ignore_index_errors=>true) do
      primary_key :id
      Integer :rubygem_id
      String :home, :size=>255
      String :wiki, :size=>255
      String :docs, :size=>255
      String :mail, :size=>255
      String :code, :size=>255
      String :bugs, :size=>255
      DateTime :created_at
      DateTime :updated_at

      index [:rubygem_id], :name=>:index_linksets_on_rubygem_id
    end

    alter_table :dependencies do
      add_column :created_at, DateTime
      add_column :updated_at, DateTime
      add_column :unresolved_name, String, :size=>255
      add_index [:unresolved_name], :name=>:index_dependencies_on_unresolved_name
    end

    alter_table :rubygems do
      add_column :created_at, DateTime
      add_column :updated_at, DateTime
      add_column :downloads, Integer, :default=>0
      add_column :slug, String, :size=>255
    end

    alter_table :versions do
      add_column :created_at, DateTime
      add_column :updated_at, DateTime
      add_column :authors, String, :text=>true
      add_column :description, String, :text=>true
      add_column :built_at, DateTime
      add_column :rubyforge_project, String, :size=>255
      add_column :position, Integer
      add_column :latest, TrueClass
      add_index [:created_at], :name=>:index_versions_on_created_at
      add_index [:built_at], :name=>:index_versions_on_built_at
      add_index [:position], :name=>:index_versions_on_position
    end
  end
end
