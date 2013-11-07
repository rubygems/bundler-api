Sequel.migration do
  no_transaction

  up do
    run <<-SQL
      CREATE INDEX CONCURRENTLY index_dependencies_on_rubygem_id_and_scope_is_runtime
      ON dependencies(rubygem_id, scope)
      WHERE scope='runtime'
SQL
  end

  down do
    run "DROP INDEX index_dependencies_on_rubygem_id_and_scope_is_runtime"
  end
end
