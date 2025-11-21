# Subscription management system

## Requirements / dependencies

- Ruby on Rails 8.x
- PostgreSQL

## Getting Started

```bash
bundle install
rails db:setup
rails test                  # Run test suite (requires 90% coverage)
OPEN_EMAILS=1 rails test    # View emails in browser during tests
rails server                # Start API server on port 3000
```

## Architecture

- Rails 8 API-only application
- Uses service object pattern for business logic
- Background job processing handled through Solid Queue
- Event sourcing pattern for audit trail

## Design decisions

- Unique constraint on [transaction_id, event_type, purchase_date] to ensure we don't process duplicate webhooks. Production would ideally use some kind of ID for this.
- Async processing - webhooks stored as events immediately, then processed asynchronously
- Users can be soft-deleted, preserving subscription history even after users leave

## Scalability considerations

- Async pattern helps prevents timeouts
- Basic indexing on potential high-traffic queries
- Batch expiration job - can be parallelized if needed
- Raw webhook data stored as JSONB

## Testing approach

- In general - a focus on behvior over implementation details
- Integration tests for full user journeys
- Controller tests for edge cases
- Job tests for retry behavior
- Model tests for remaining edge cases
- 100% line and branch coverage

## Out of scope

- Multiple subscription providers
- Webhook verification
- Out-of-order webhooks
- Authentication/authorization
- Rate limiting
- Monitoring/alerting for stuck events
- Upgrades/downgrades (plan changes)

## API endpoints

### POST /api/v1/subscriptions

Creates a provisional subscription after client-side payment completion.

#### Request

```json
{
  "user_id": "123",
  "transaction_id": "apple_txn_abc123",
  "product_id": "com.samansa.subscription.monthly"
}
```

#### Success (201)
```json
{
  "subscription_id": 1,
  "status": "provisional",
  "transaction_id": "apple_txn_abc123",
  "message": "subscription initiated. awaiting confirmation"
}
```

#### Errors

- 404 - User not found
- 422 - Validation error (subscription already active, missing fields)

### POST /webhooks/apple

Receives webhook notifications from Apple for subscription lifecycle events.

#### Request
```json
{
  "type": "PURCHASE",
  "transaction_id": "apple_txn_abc123",
  "product_id": "com.samansa.subscription.monthly",
  "amount": "9.99",
  "currency": "USD",
  "purchase_date": "2025-10-01T12:00:00Z",
  "expires_date": "2025-11-01T12:00:00Z"
}
```

#### Event Types:

- PURCHASE - Subscription confirmed
- RENEW - Subscription auto-renewed
- CANCEL - User cancelled (remains valid until expires_date)

#### Success (200)

- Empty body
- Idempotent - duplicate webhooks should return 200 without processing

#### Errors

- 422 - Subscription not found (transaction_id doesn't match any existing subscription)

