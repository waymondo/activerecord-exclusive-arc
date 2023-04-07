require "test_helper"

class VersionTest < ActiveSupport::TestCase
  test "it has a version number" do
    refute_nil ::ExclusiveArc::VERSION
  end
end
