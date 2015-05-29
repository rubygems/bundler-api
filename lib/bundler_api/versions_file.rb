require 'bundler_api'

class BundlerApi::VersionsFile
  PATH = "versions.list"
  def initialize(connection)
    @conn = connection
  end

  def update(file = nil)
    file ||= PATH
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

    content = Time.now.to_i.to_s
    content += "\n---\n"
    content += dataset.map { |entry| "#{entry[:name]} #{entry[:string_agg]}" }.join("\n")

    File.open(file, 'w') do |io|
      io.write content
    end
  end

  private
    def content
      File.open(PATH).read
    end

    def created_at
      File.open(PATH).readline
    end
end
