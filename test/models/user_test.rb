require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "user with no active subscription at all can't watch" do
    user = users(:bob)
    user.subscriptions.destroy_all
    assert !user.can_watch?
  end
end
