class BundlerApi::Checksum
  attr_reader :checksum, :name

  def initialize(conn, name)
    @conn, @name = conn, name
    row = @conn[:rubygems].select(:deps_md5).where(name: @name).first
    @checksum = row[:deps_md5] if row
  end

  def checksum=(sum)
    @conn[:rubygems].where(name: @name).update(deps_md5: sum)
  end
end