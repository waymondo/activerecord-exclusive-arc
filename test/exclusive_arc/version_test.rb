require "test_helper"

class VersionTest < Minitest::Test
  def test_it_has_a_version
    refute_nil ::ExclusiveArc::VERSION
  end
end
