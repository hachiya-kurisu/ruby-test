module SubscriptionErrors
  class InvalidTransition < StandardError; end
  class AlreadySubscribed < StandardError; end
end
