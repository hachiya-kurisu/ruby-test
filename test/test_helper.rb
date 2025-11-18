ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Coverage
    SimpleCov.start "rails" do
      enable_coverage :branch
      primary_coverage :branch

      add_filter "/test/"
      add_filter "/config/"

      add_group "Models", "app/models"
      add_group "Controllers", "app/controllers"
      add_group "Jobs", "app/jobs"

      minimum_coverage line: 100, branch: 100
    end

    # clear email deliveries before each test (needed for OPEN_EMAILS=1)
    def setup
      ActionMailer::Base.deliveries.clear
    end
  end
end
