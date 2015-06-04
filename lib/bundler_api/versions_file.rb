require 'bundler_api'

class BundlerApi::VersionsFile
  PATH = "versions.list"
  def initialize(connection)
    @conn = connection
  end

  def create_or_update
    if File.exists? PATH
      update
    else
      create
    end
  end

  def create
    content = Time.now.to_i.to_s
    content += "\n---\n"
    content += gems_with_versions

    File.open(PATH, 'w') do |io|
      io.write content
    end
  end

  def update
    to_write = with_new_gems
    File.open(PATH, 'w') do |io|
      io.write to_write
    end
  end

  def with_new_gems
    if gems_with_versions(created_at).empty?
      content
    else
      content + "\n" + gems_with_versions(created_at)
    end
  end

  private
    def content
      File.open(PATH).read
    end

    def created_at
      DateTime.parse(File.mtime(PATH).to_s)
    end

    def gems_with_versions(newer_than = nil)
      if newer_than
        dataset = @conn[<<-SQL, newer_than]
            SELECT
              r.name, string_agg(
                        concat_ws('-', v.number, nullif(v.platform,'ruby')), ','
                        ORDER BY number ASC
                      )
            FROM rubygems AS r, versions AS v
            WHERE v.rubygem_id = r.id AND
                  v.indexed is true AND
                  v.created_at > ?
            GROUP BY r.name
        SQL
      else
        dataset = @conn[<<-SQL]
            SELECT
              r.name, string_agg(
                        concat_ws('-', v.number, nullif(v.platform,'ruby')), ','
                        ORDER BY number ASC
                      )
            FROM rubygems AS r, versions AS v
            WHERE v.rubygem_id = r.id AND v.indexed is true
            GROUP BY r.name
        SQL
      end
      dataset.map { |entry| "#{entry[:name]} #{entry[:string_agg]}" }.join("\n")
    end
end
