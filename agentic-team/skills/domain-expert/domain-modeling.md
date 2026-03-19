# Skill: Domain Modeling (DDD)

> Load this skill when: A new feature requires understanding business rules,
> domain entities, and their relationships before code is written.

## Context

In 100% AI development, domain models are the SINGLE SOURCE OF TRUTH for business
logic. AI agents don't have years of institutional knowledge — the domain model
must capture every business concept, rule, and constraint explicitly. If a rule
isn't in the model, it won't be in the code.

## Domain Modeling Protocol

### Phase 1: Domain Discovery (Event Storming)

Walk through the business process and identify:

```
DOMAIN EVENTS (things that happen — past tense):
  - UserRegistered
  - OrderPlaced
  - PaymentReceived
  - PaymentFailed
  - OrderShipped
  - OrderDelivered
  - OrderReturned
  - RefundIssued

COMMANDS (things that trigger events — imperative):
  - RegisterUser
  - PlaceOrder
  - ProcessPayment
  - ShipOrder
  - ReturnOrder
  - IssueRefund

AGGREGATES (clusters of entities that change together):
  - User (root) → Profile, Preferences, Sessions
  - Order (root) → OrderLines, ShippingAddress, Payment
  - Product (root) → Variants, Inventory, Pricing

ACTORS (who triggers commands):
  - Customer → RegisterUser, PlaceOrder, ReturnOrder
  - System → ProcessPayment (automatic), SendNotification
  - Admin → ShipOrder, IssueRefund, SuspendUser
```

### Phase 2: Bounded Context Map

```
BOUNDED CONTEXTS:

┌─────────────────────┐    ┌─────────────────────┐
│   IDENTITY CONTEXT  │    │   CATALOG CONTEXT    │
│                     │    │                     │
│  User (aggregate)   │    │  Product (aggregate) │
│  - Registration     │    │  - Listing           │
│  - Authentication   │    │  - Search            │
│  - Profile          │    │  - Categories        │
│                     │    │                     │
│  "User" = identity  │    │  "Product" = catalog │
│  + credentials      │    │  item with variants  │
└────────┬────────────┘    └────────┬────────────┘
         │                          │
         │    ┌─────────────────┐   │
         └───→│  ORDER CONTEXT  │←──┘
              │                 │
              │  Order (aggr.)  │
              │  - Placement    │
              │  - Fulfillment  │
              │  - Returns      │
              │                 │
              │  "User" = buyer │
              │  (just ID+name) │
              │  "Product" =    │
              │  line item (SKU │
              │  + price + qty) │
              └────────┬────────┘
                       │
              ┌────────▼────────┐
              │ PAYMENT CONTEXT │
              │                 │
              │  Payment (aggr.)│
              │  - Charge       │
              │  - Refund       │
              │  - Reconcile    │
              │                 │
              │  "Order" = just │
              │  an amount +    │
              │  reference ID   │
              └─────────────────┘

CONTEXT RELATIONSHIPS:
  Identity → Order:    Customer/Supplier (Identity provides user data)
  Catalog → Order:     Customer/Supplier (Catalog provides product data)
  Order → Payment:     Customer/Supplier (Order requests payment)

TRANSLATION RULES:
  Identity.User    → Order.Buyer      (only ID, name, email)
  Catalog.Product  → Order.LineItem   (only SKU, name, price at time of order)
  Order.Order      → Payment.Charge   (only amount, currency, reference)
```

### Phase 3: Aggregate Design

For each aggregate, define:

```
AGGREGATE: Order
ROOT ENTITY: Order

ENTITIES:
  Order:
    id:           OrderId (UUID)
    buyer_id:     UserId (reference to Identity context)
    status:       OrderStatus (enum)
    placed_at:    DateTime
    shipped_at:   DateTime? (nullable until shipped)
    total:        Money (value object)

  OrderLine:
    id:           OrderLineId (UUID)
    order_id:     OrderId (FK)
    sku:          SKU (value object)
    product_name: String (snapshot at time of order)
    unit_price:   Money (snapshot at time of order)
    quantity:     PositiveInteger
    line_total:   Money (computed: unit_price × quantity)

VALUE OBJECTS (immutable, no identity):
  Money:
    amount:   Decimal (2 decimal places)
    currency: CurrencyCode (ISO 4217: USD, EUR, GBP)

  SKU:
    value:    String (format: [A-Z]{2}-[0-9]{6})

  OrderStatus:
    values:   [draft, placed, confirmed, shipped, delivered, returned, cancelled]
    transitions:
      draft     → [placed, cancelled]
      placed    → [confirmed, cancelled]
      confirmed → [shipped, cancelled]
      shipped   → [delivered, returned]
      delivered → [returned]
      returned  → [] (terminal)
      cancelled → [] (terminal)

INVARIANTS (rules that MUST ALWAYS be true):
  INV-1: Order.total == SUM(OrderLine.line_total) — total must match lines
  INV-2: Order must have at least 1 OrderLine — no empty orders
  INV-3: OrderLine.quantity > 0 — no zero-quantity lines
  INV-4: OrderLine.unit_price >= 0 — no negative prices
  INV-5: Status transitions must follow the state machine — no jumping states
  INV-6: shipped_at must be null until status = shipped
  INV-7: Max 50 OrderLines per Order — business rule
  INV-8: Order.total <= $10,000 without admin approval

DOMAIN EVENTS EMITTED:
  OrderPlaced:    { order_id, buyer_id, total, line_count, placed_at }
  OrderConfirmed: { order_id, confirmed_at }
  OrderShipped:   { order_id, tracking_number, shipped_at }
  OrderCancelled: { order_id, reason, cancelled_at, cancelled_by }
```

### Phase 4: Ubiquitous Language Dictionary

```
| Term | Definition | NOT this | Context |
|------|-----------|----------|---------|
| Order | A buyer's intent to purchase items | Not a "transaction" or "purchase" | Order Context |
| OrderLine | A single product+quantity in an order | Not a "cart item" or "product" | Order Context |
| Buyer | The person placing an order | Not a "user" (that's Identity) | Order Context |
| SKU | Stock Keeping Unit — unique product variant | Not a "product ID" | Catalog + Order |
| Money | Amount + currency pair | Not a bare number or float | All Contexts |
| Placed | Order submitted by buyer, awaiting confirmation | Not "created" or "submitted" | Order Context |
| Confirmed | Order validated and payment authorized | Not "approved" or "accepted" | Order Context |
```

## Output Format

```json
{
  "bounded_contexts": ["identity", "catalog", "order", "payment"],
  "aggregates": {
    "order": {
      "root": "Order",
      "entities": ["Order", "OrderLine"],
      "value_objects": ["Money", "SKU", "OrderStatus"],
      "invariants": 8,
      "domain_events": ["OrderPlaced", "OrderConfirmed", "OrderShipped", "OrderCancelled"]
    }
  },
  "ubiquitous_language_terms": 7,
  "context_relationships": 3
}
```

## Handoff

- **Architect** → bounded context boundaries inform service design
- **Backend Dev** → entities, value objects, invariants become code
- **QA** → invariants become test assertions, edge cases become test scenarios
- **Frontend Dev** → ubiquitous language informs UI copy and field names
