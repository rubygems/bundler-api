require 'zlib'

class DepCalc
  def initialize(data)
    marshal48 = Marshal.load(Zlib::Inflate.inflate(File.read(data)))
    @gems = {}

    marshal48.each do |name, spec|

      @gems[spec.name] = [] unless @gems[spec.name]
      @gems[spec.name] << spec
    end

    nil
  end

  # @param [String] array of strings with the gem names
  def deps_for(gems)
    gems.map do |gem_name|
      specs = @gems[gem_name]

      if specs
        specs.map do |spec|
          {
            :name         => spec.name,
            :number       => spec.version.version,
            :platform     => spec.platform.to_s,
            :dependencies => spec.dependencies.select {|dep| dep.type == :runtime }.map do |dep|
              [dep.name, dep.requirement.requirements.map {|a| a.join(" ") }.join(", ")]
            end
          }
        end
      end
    end.compact.flatten
  end
end
