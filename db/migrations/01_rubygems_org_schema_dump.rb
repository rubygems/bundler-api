Sequel.migration do
  change do
    create_table(:dependencies, :ignore_index_errors=>true) do
      primary_key :id
      String :requirements, :size=>255
      DateTime :created_at
      DateTime :updated_at
      Integer :rubygem_id
      Integer :version_id
      String :scope, :size=>255
      String :unresolved_name, :size=>255
      
      index [:rubygem_id], :name=>:index_dependencies_on_rubygem_id
      index [:unresolved_name], :name=>:index_dependencies_on_unresolved_name
      index [:version_id], :name=>:index_dependencies_on_version_id
    end
    
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
    
    create_table(:rubygems, :ignore_index_errors=>true) do
      primary_key :id
      String :name, :size=>255
      DateTime :created_at
      DateTime :updated_at
      Integer :downloads, :default=>0
      String :slug, :size=>255
      
      index [:name], :name=>:index_rubygems_on_name, :unique=>true
    end
    
    create_table(:versions, :ignore_index_errors=>true) do
      primary_key :id
      String :authors, :text=>true
      String :description, :text=>true
      String :number, :size=>255
      Integer :rubygem_id
      DateTime :built_at
      DateTime :updated_at
      String :rubyforge_project, :size=>255
      String :summary, :text=>true
      String :platform, :size=>255
      DateTime :created_at
      TrueClass :indexed, :default=>true
      TrueClass :prerelease
      Integer :position
      TrueClass :latest
      String :full_name, :size=>255
      
      index [:built_at], :name=>:index_versions_on_built_at
      index [:created_at], :name=>:index_versions_on_created_at
      index [:full_name], :name=>:index_versions_on_full_name
      index [:indexed], :name=>:index_versions_on_indexed
      index [:number], :name=>:index_versions_on_number
      index [:position], :name=>:index_versions_on_position
      index [:prerelease], :name=>:index_versions_on_prerelease
      index [:rubygem_id], :name=>:index_versions_on_rubygem_id
      index [:rubygem_id, :number, :platform], :name=>:index_versions_on_rubygem_id_and_number_and_platform, :unique=>true
    end
  end
end
