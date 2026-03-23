# Branch Report: Item-properties,-Search-item

## Branch purpose

This branch adds item management and search-related features to the project. It extends the application with item properties, item listing and detail pages, item search, and bid display on the item detail page. It also updates the CI workflow so the branch can run with a consistent Ruby version and a single GitHub Actions pipeline.

## Main features in this branch

### 1. Item model and item properties

The branch introduces an `Item` model with the following properties:

- `name`
- `description`
- `price`
- `category`
- `available`
- timestamps

The model also defines:

- association with bids
- highest bid lookup
- search support
- category filtering
- price range filtering
- sorting support

### 2. Item search

This branch adds item search so users can search items by keyword.

- On SQLite, search falls back to `LIKE` on name and description.
- On databases that support full-text search, the model uses `MATCH ... AGAINST`.

This makes the feature usable in local development while keeping compatibility with fuller search behavior in other environments.

### 3. Item pages

This branch adds the main item pages:

- item index page
- item detail page
- item creation form
- item search form

The item detail page was also upgraded for demo use with:

- improved layout and styling
- item summary cards
- current highest bid display
- bid history table
- bid submission form
- success and validation messages

### 4. Bid display and bid validation in the item page

The detail page now shows the bid history for an item and allows users to place a bid directly from the page.

The bidding logic includes validation for the current highest bid:

- a new bid must be greater than the current highest bid
- errors are shown on the page if the bid is invalid
- successful bids redirect back to the item detail page with a notice

### 5. Routing and controller support

This branch adds routing and controller support for:

- item listing
- item creation
- item detail view
- item search

The repository currently contains both Rails-style controller/routes files and Sinatra app routes. The active demo flow in this branch is implemented in the Sinatra app entry point and views.

### 6. Database and migration work

This branch adds item-related schema support, including a migration for creating items with a full-text index.

For local Sinatra execution, the app also contains schema bootstrap logic that creates `items` and `bids` tables if they do not already exist in the SQLite development database.

### 7. Test coverage for item functionality

This branch adds and updates tests related to item and bid behavior, including:

- item model specs
- bid specs
- item factory
- updates to existing specs affected by the new item functionality

### 8. CI and Ruby version alignment

This branch also improves the project setup for CI:

- duplicate GitHub Actions workflows were merged into a single workflow
- the CI workflow now reads the Ruby version from `.ruby-version`
- this avoids Ruby version mismatch between local development and GitHub Actions

## Files added or updated

Key files changed in this branch include:

- `app.rb`
- `app/models/item.rb`
- `app/models/bid.rb`
- `app/controllers/items_controller.rb`
- `app/helpers/items_helper.rb`
- `app/views/items/index.erb`
- `app/views/items/index.html.erb`
- `app/views/items/show.erb`
- `app/views/items/show.html.erb`
- `config/routes.rb`
- `db/migrate/20260323000000_create_items_with_fulltext_index.rb`
- `spec/models/item_spec.rb`
- `spec/models/bid_spec.rb`
- `spec/factories/items.rb`
- `.github/workflows/ci.yml`

Removed:

- `.github/workflows/blank.yml`

## Summary of branch outcome

In summary, this branch delivers:

1. item properties and persistence support
2. item index and detail pages
3. item creation flow
4. item search capability
5. bid display and bid placement on the item detail page
6. tests for the new item-related behavior
7. cleaner CI setup with consistent Ruby version handling

## Notes for reviewers

- The main user-facing feature in this branch is item search and item detail management.
- The detail page is now presentation-ready for demo usage.
- CI behavior was simplified so only one workflow runs instead of two duplicate pipelines.
- Local demo startup should use Puma with host `0.0.0.0` and port `4567`.

## Suggested demo points

When presenting this branch, the most useful flow is:

1. open the item list page
2. create a new item with properties
3. search for an item by keyword
4. open the item detail page
5. place a bid
6. show highest bid and bid history updating after submission