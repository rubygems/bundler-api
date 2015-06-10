require 'bundler_api'
require 'bundler_api/cdn'

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
    content += gems_for_new_file

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
    if new_gems.empty?
      content
    else
      content + "\n" + new_gems
    end
  end

  private
    def content
      File.open(PATH).read

    end

    def created_at
      DateTime.parse(File.mtime(PATH).to_s)
    end

    def gems_for_new_file
      dataset = @conn[<<-SQL]
          SELECT
            r.name, string_agg(
                      concat_ws('-', v.number, nullif(v.platform,'ruby')), ','
                      ORDER BY number ASC
                    )
          FROM rubygems AS r, versions AS v
          WHERE v.rubygem_id = r.id AND
                v.indexed is true
          GROUP BY r.name
      SQL
      dataset.map { |entry| "#{entry[:name]} #{entry[:string_agg]}" }.join("\n")
    end

    def new_gems
      dataset = @conn[<<-SQL, created_at]
          SELECT r.name, concat_ws('-', v.number, nullif(v.platform,'ruby'))
          FROM rubygems AS r, versions AS v
          WHERE v.rubygem_id = r.id AND v.indexed is true AND v.created_at > ?
          ORDER BY v.created_at, r.name, concat_ws
      SQL
      dataset.map { |entry| "#{entry[:name]} #{entry[:concat_ws]}" }.join("\n")
    end
end
