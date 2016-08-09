require 'sequel'
require 'spec_helper'
require 'bundler_api/gem_info'
require 'support/gem_builder'

describe BundlerApi::GemInfo do
  let(:db)       { $db }
  let(:builder)  { GemBuilder.new(db) }
  let(:gem_info) { BundlerApi::GemInfo.new(db) }

  describe "#deps_for" do
    context "no gems" do
      it "should find the deps" do
        expect(gem_info.deps_for('rack')).to eq([])
      end
    end

    context "no dependencies" do
      before do
        rack_id = builder.create_rubygem('rack')
        builder.create_version(rack_id, 'rack')
      end

      it "should return rack" do
        result = {
          name:         'rack',
          number:       '1.0.0',
          platform:     'ruby'
        }

        result.each_pair do |k, v|
          expect(gem_info.deps_for('rack').first[k]).to eq(v)
        end
      end
    end

    context "has one dependency" do
      before do
        tomorrow = Time.at(Time.now.to_i + 86400)

        rack_id         = builder.create_rubygem('rack')
        rack_version_id = builder.create_version(rack_id, 'rack')
        rack_version_id2 = builder.create_version(rack_id, 'rack', '1.1.9', 'ruby', time: tomorrow)
        rack_version_id2 = builder.create_version(rack_id, 'rack', '1.2.0', 'ruby', time: tomorrow)

        foo_id = builder.create_rubygem('foo')
        builder.create_version(foo_id, 'foo')
        builder.create_dependency(foo_id, rack_version_id, "= 1.0.0")
      end

      it "should return foo as a dep of rack" do
        result = {
          name:         'rack',
          number:       '1.0.0',
          platform:     'ruby',
          dependencies: [['foo', '= 1.0.0']]
        }

        result.each_pair do |k,v|
          expect(gem_info.deps_for('rack').first[k]).to eq(v)
        end
      end

      it "order by created_at and version number" do
        result = %w(1.0.0 1.1.9 1.2.0)
        expect(gem_info.deps_for('rack').map { |x| x[:number] }).to eq(result)
      end
    end

    context "filters on indexed" do
      before do
        rack_id                     = builder.create_rubygem('rack')
        rack_version_id             = builder.create_version(rack_id, 'rack', '1.1.0')
        non_indexed_rack_version_id = builder.create_version(rack_id, 'rack', '1.0.0', 'ruby', { indexed: false })

        foo_id = builder.create_rubygem('foo')
        builder.create_version(foo_id, 'foo')
        builder.create_dependency(foo_id, rack_version_id, "= 1.0.0")
        builder.create_dependency(foo_id, non_indexed_rack_version_id, "= 1.0.0")
      end

      it "should not return nonindexed gems" do
        result = {
          name:         'rack',
          number:       '1.1.0',
          platform:     'ruby',
          dependencies: [['foo', '= 1.0.0']]
        }

        result.each_pair do |k,v|
          expect(gem_info.deps_for('rack').first[k]).to eq(v)
        end
      end
    end
  end

  describe "#names" do
    before do
      builder.create_rubygem("a")
      builder.create_rubygem("c")
      builder.create_rubygem("b")
      builder.create_rubygem("d")
    end

    it "should return the list back in order" do
      expect(gem_info.names).to eq(%w(a b c d))
    end
  end

  describe "#versions" do
    let(:gems) do
      [
        CompactIndex::Gem.new(
          'a',
          [CompactIndex::GemVersion.new('1.0.0', 'ruby', nil, 'a100')]
        ),
        CompactIndex::Gem.new(
          'a',
          [CompactIndex::GemVersion.new('1.0.1', 'ruby', nil, 'a101')]
        ),
        CompactIndex::Gem.new(
          'b',
          [CompactIndex::GemVersion.new('1.0.0', 'ruby', nil, 'b100')]
        ),
        CompactIndex::Gem.new(
          'c',
          [CompactIndex::GemVersion.new('1.0.0', 'java', nil, 'c100')]
        ),
        CompactIndex::Gem.new(
          'a',
          [CompactIndex::GemVersion.new('2.0.0', 'java', nil, 'a200')]
        ),
        CompactIndex::Gem.new(
          'a',
          [CompactIndex::GemVersion.new('2.0.1', 'ruby', nil, 'a201')]
        )
      ]
    end

    let(:a) { a = builder.create_rubygem("a") }

    before do
      @time = Time.now
      builder.create_version(a, 'a', '1.0.0', 'ruby', info_checksum: 'a100')
      builder.create_version(a, 'a', '1.0.1', 'ruby', info_checksum: 'a101')
      b = builder.create_rubygem("b")
      builder.create_version(b, 'b', '1.0.0', 'ruby', info_checksum: 'b100')
      c = builder.create_rubygem("c")
      builder.create_version(c, 'c', '1.0.0', 'java', info_checksum: 'c100')
      @a200 = builder.create_version(a, 'a', '2.0.0', 'java', info_checksum: 'a200')
      builder.create_version(a, 'a', '2.0.1', 'ruby', info_checksum: 'a201')
    end

    it "should return gems on compact index format" do
      expect(gem_info.versions(@time)).to eq(gems)
    end

    context "with yanked gems" do
      before do
        builder.yank(@a200, yanked_info_checksum: 'a200y')
        builder.create_version(a, 'a', '2.2.2', 'ruby', info_checksum: 'a222')
      end

      let(:gems_with_yanked) do
        gems + [
          CompactIndex::Gem.new(
            'a',
            [CompactIndex::GemVersion.new('-2.0.0', 'java', nil, 'a200y')]
          ),
          CompactIndex::Gem.new(
            'a',
            [CompactIndex::GemVersion.new('2.2.2', 'ruby', nil, 'a222')]
          )
        ]
      end

      it "return yanked gems with minus version" do
        expect(gem_info.versions(@time, true)).to eq(gems_with_yanked)
      end
    end
  end

  describe "#info" do
    before do
      info_test = builder.create_rubygem('info_test')
      builder.create_version(info_test, 'info_test', '1.0.0', 'ruby', checksum: 'abc123')

      info_test101= builder.create_version(info_test, 'info_test', '1.0.1', 'ruby', checksum: 'qwerty')
      [['foo', '= 1.0.0'], ['bar', '>= 2.1, < 3.0']].each do |dep, requirements|
        dep_id = builder.create_rubygem(dep)
        builder.create_dependency(dep_id, info_test101, requirements)
      end
    end

    it "return compact index info for a gem" do
      expected = "---\n1.0.0 |checksum:abc123\n1.0.1 bar:< 3.0&>= 2.1,foo:= 1.0.0|checksum:qwerty\n"
      expect(gem_info.info('info_test')).to eq(expected)
    end
  end
end
