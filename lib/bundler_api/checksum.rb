class BundlerApi::Checksum
  attr_reader :checksum, :name

  def initialize(conn, name)
    @conn = conn
    @name = name
    row = @conn[:rubygems].where(name: @name).first

    if row
      @exists = true
      @checksum = row[:deps_md5]
    end
  end

  def checksum=(sum)
    if @exists
      @conn[:rubygems].where(name: @name).update(deps_md5: sum)
    else
      @conn[:rubygems].insert(name: @name, deps_md5: sum)
    end

    @checksum = sum
  end

end
