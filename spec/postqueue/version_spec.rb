require "spec_helper"

describe "::Postqueue" do
  it "reports a version" do
    expect(Postqueue::VERSION).to satisfy { |s| s =~ /\d\.\d+\.\d+/ }
  end
end
