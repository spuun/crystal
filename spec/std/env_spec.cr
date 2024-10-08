require "spec"
require "./spec_helper"

describe "ENV" do
  # Preserves the existing environment for each spec.
  # To avoid potential circular definitions, this has to use the system methods
  # directly, rather than `ENV` or `with_env`.
  around_each do |example|
    old_env = {} of String => String
    Crystal::System::Env.each { |key, value| old_env[key] = value }

    begin
      example.run
    ensure
      keys = [] of String
      Crystal::System::Env.each { |key| keys << key }
      keys.each { |key| Crystal::System::Env.set(key, nil) }
      old_env.each { |key, value| Crystal::System::Env.set(key, value) }
    end
  end

  it "gets non existent key raises" do
    expect_raises KeyError, "Missing ENV key: \"NON-EXISTENT\"" do
      ENV["NON-EXISTENT"]
    end
  end

  it "gets non existent key as nilable" do
    ENV["NON-EXISTENT"]?.should be_nil
  end

  it "set and gets" do
    (ENV["FOO"] = "1").should eq("1")
    ENV["FOO"].should eq("1")
    ENV["FOO"]?.should eq("1")
  end

  {% if flag?(:win32) %}
    it "sets and gets case-insensitive" do
      (ENV["FOO"] = "1").should eq("1")
      ENV["Foo"].should eq("1")
      ENV["foo"]?.should eq("1")
    end
  {% else %}
    it "sets and gets case-sensitive" do
      ENV["FOO"] = "1"
      ENV["foo"]?.should be_nil
    end
  {% end %}

  it "sets to nil (same as delete)" do
    ENV["FOO"] = "1"
    ENV["FOO"]?.should_not be_nil
    ENV["FOO"] = nil
    ENV["FOO"]?.should be_nil
  end

  it "sets to empty string" do
    (ENV["FOO_EMPTY"] = "").should eq ""
    ENV["FOO_EMPTY"]?.should eq ""
  end

  it "does has_key?" do
    ENV["FOO"] = "1"
    ENV.has_key?("NON_EXISTENT").should be_false
    ENV.has_key?("FOO").should be_true
  end

  it "deletes a key" do
    ENV["FOO"] = "1"
    ENV.delete("FOO").should eq("1")
    ENV.delete("FOO").should be_nil
    ENV.has_key?("FOO").should be_false
  end

  it "does .keys" do
    %w(FOO BAR).each { |k| ENV.keys.should_not contain(k) }
    ENV["FOO"] = ENV["BAR"] = "1"
    %w(FOO BAR).each { |k| ENV.keys.should contain(k) }
  end

  it "does not have an empty key" do
    # Setting an empty key is invalid on both POSIX and Windows. So reporting an empty key
    # would always be a bug. And there *was* a bug - see win32/ Crystal::System::Env.each
    ENV.keys.should_not contain("")
  end

  it "does .values" do
    [1, 2].each { |i| ENV.values.should_not contain("SOMEVALUE_#{i}") }
    ENV["FOO"] = "SOMEVALUE_1"
    ENV["BAR"] = "SOMEVALUE_2"
    [1, 2].each { |i| ENV.values.should contain("SOMEVALUE_#{i}") }
  end

  describe "[]=" do
    it "disallows NUL-bytes in key" do
      expect_raises(ArgumentError, "String `key` contains null byte") do
        ENV["FOO\0BAR"] = "something"
      end
    end

    it "disallows NUL-bytes in key if value is nil" do
      expect_raises(ArgumentError, "String `key` contains null byte") do
        ENV["FOO\0BAR"] = nil
      end
    end

    it "disallows NUL-bytes in value" do
      expect_raises(ArgumentError, "String `value` contains null byte") do
        ENV["FOO"] = "BAR\0BAZ"
      end
    end
  end

  describe "fetch" do
    it "fetches with one argument" do
      ENV["1"] = "2"
      ENV.fetch("1").should eq("2")
    end

    it "fetches with default value" do
      ENV["1"] = "2"
      ENV.fetch("1", "3").should eq("2")
      ENV.fetch("2", "3").should eq("3")
    end

    it "fetches with block" do
      ENV["1"] = "2"
      ENV.fetch("1") { |k| k + "block" }.should eq("2")
      ENV.fetch("2") { |k| k + "block" }.should eq("2block")
      ENV.fetch("3") { 4 }.should eq(4)
    end

    it "fetches and raises" do
      ENV["1"] = "2"
      expect_raises KeyError, "Missing ENV key: \"2\"" do
        ENV.fetch("2")
      end
    end

    it "fetches arbitrary default value" do
      ENV.fetch("nonexistent", true).should be_true
    end
  end

  it "handles unicode" do
    ENV["TEST_UNICODE_1"] = "bar\u{d7ff}\u{10000}"
    ENV["TEST_UNICODE_2"] = "\u{1234}"
    ENV["TEST_UNICODE_1"].should eq "bar\u{d7ff}\u{10000}"
    ENV["TEST_UNICODE_2"].should eq "\u{1234}"

    values = {} of String => String
    ENV.each do |key, value|
      if key.starts_with?("TEST_UNICODE_")
        values[key] = value
      end
    end
    values.should eq({
      "TEST_UNICODE_1" => "bar\u{d7ff}\u{10000}",
      "TEST_UNICODE_2" => "\u{1234}",
    })
  end

  it "#to_h" do
    ENV["FOO"] = "foo"
    ENV.to_h["FOO"].should eq "foo"
  end

  {% if flag?(:win32) %}
    it "skips internal environment variables" do
      key = "=#{Path[Dir.current].drive}"
      ENV.has_key?(key).should be_false
      ENV[key]?.should be_nil
      expect_raises(ArgumentError) { ENV[key] = "foo" }
      expect_raises(ArgumentError) { ENV[key] = nil }
    end
  {% end %}
end
