class BundlerApi::Checksum
  attr_reader :checksum, :name

  def initialize(conn, name)
    @conn = conn
    @name = name
    row = @conn[:checksums].where(name: @name).first

    if row
      @exists = true
      @checksum = row[:md5]
    end
  end

  def checksum=(sum)
    if @exists
      @conn[:checksums].where(name: @name).update(md5: sum)
    else
      @conn[:checksums].insert(name: @name, md5: sum)
    end

    @checksum = sum
  end

end
