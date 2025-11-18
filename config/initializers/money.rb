# encoding : utf-8

MoneyRails.configure do |config|
  config.default_currency = :jpy

  config.include_validations = false

  Money.rounding_mode = BigDecimal::ROUND_HALF_UP
end
