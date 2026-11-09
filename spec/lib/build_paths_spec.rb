require "yaml"

describe "tensorbuzz.yml build paths" do
  let(:config) { YAML.load_file(File.expand_path("../../tensorbuzz.yml", __dir__)) }
  let(:builds) { config.fetch("builds") }

  def glob_source(pattern)
    pattern.scan(/\*\*\/|\*\*|\*|\?|\[[^\]]*\]|[^*?\[\]]+/).map do |token|
      if token == "**/"
        "(?:[^/]+/)*"
      elsif token == "**"
        ".*"
      elsif token == "*"
        "[^/]*"
      elsif token == "?"
        "[^/]"
      elsif token.start_with?("[")
        token.sub(/\A\[!/, "[^")
      else
        Regexp.escape(token)
      end
    end.join
  end

  def glob_regexp(pattern)
    pattern_body = pattern.sub(%r{\A/+}, "").delete_suffix("/")
    source = glob_source(pattern_body)
    source = "(?:[^/]+/)*#{source}" unless pattern.include?("/")
    source = "#{source}(?:/.*)?" unless pattern_body.end_with?("**")

    Regexp.new("\\A#{source}\\z")
  end

  def claimed_by?(patterns, changed_path)
    last_match = nil

    patterns.each do |pattern|
      negated = pattern.start_with?("!")
      pattern_body = negated ? pattern[1..] : pattern
      last_match = negated if glob_regexp(pattern_body).match?(changed_path)
    end

    last_match == false
  end

  def lanes_claiming(changed_paths)
    builds.filter_map do |build_identifier, build_config|
      next if changed_paths.none? { |changed_path| claimed_by?(build_config.fetch("paths"), changed_path) }

      build_identifier
    end
  end

  it "keeps paths off the root config, which declares builds" do
    expect(config).not_to have_key("paths")
  end

  it "declares a non-empty glob list on every build" do
    builds.each do |build_identifier, build_config|
      patterns = build_config["paths"]

      expect(patterns).to be_a(Array), "builds.#{build_identifier}.paths must be an array"
      expect(patterns).not_to be_empty
      patterns.each do |pattern|
        expect(pattern).to be_a(String), "builds.#{build_identifier}.paths has #{pattern.inspect}"
        expect(pattern.strip).not_to be_empty
      end
    end
  end

  it "never declares a negation with nothing after the !" do
    builds.each do |build_identifier, build_config|
      build_config.fetch("paths").each do |pattern|
        next unless pattern.start_with?("!")

        expect(pattern[1..].strip).not_to be_empty, "builds.#{build_identifier}.paths #{pattern.inspect}"
      end
    end
  end

  it "carves negations out of the directory rule they follow" do
    patterns = ["admin-app/**", "!admin-app/docs/**"]

    expect(claimed_by?(patterns, "admin-app/src/Scanner.tsx")).to be(true)
    expect(claimed_by?(patterns, "admin-app/docs/readme.md")).to be(false)
  end

  it "matches a bare name at any depth but a slashed pattern only at the root" do
    expect(claimed_by?(["Gemfile"], "Gemfile")).to be(true)
    expect(claimed_by?(["Gemfile"], "gemfiles/ruby_2_rails_6.gemfile")).to be(false)
    expect(claimed_by?(["lib/**"], "lib/active_record_query_fixer/version.rb")).to be(true)
  end

  it "runs exactly the builds that the changed paths belong to" do
    deliveries = [
      [["Gemfile.lock"], ["build_5"]],
      [["Gemfile", "Gemfile.lock"], ["build_5"]],
      [["gemfiles/ruby_2_rails_6.gemfile.lock"], ["build_1"]],
      [["gemfiles/ruby_2_rails_7.gemfile.lock"], ["build_2", "build_4"]],
      [["gemfiles/ruby_3_rails_6.gemfile"], ["build_3"]],
      [["gemfiles/ruby_3_rails_7.gemfile.lock"], ["build_4"]],
      [["Appraisals"], ["build_1", "build_2", "build_3", "build_4"]],
      [["lib/active_record_query_fixer.rb"], ["build_1", "build_2", "build_3", "build_4", "build_5"]],
      [["spec/dummy/db/schema.rb"], ["build_1", "build_2", "build_3", "build_4"]],
      [["spec/dummy/db/migrate/20261109000000_add_index.rb"], ["build_1", "build_2", "build_3", "build_4", "build_5"]],
      [["spec/dummy/log/.keep"], []],
      [["README.md"], []]
    ]

    deliveries.each do |changed_paths, expected_lanes|
      expect(lanes_claiming(changed_paths)).to eq(expected_lanes), changed_paths.inspect
    end
  end
end
