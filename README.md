cuhk 2025-2026 term2 csci3100 group project group 44

1. Overview
This document summarizes the scope, architecture, and delivery plan for the 
team’s SaaS project. It adheres to the course guidelines: single-spaced, 12-point 
Times, concise and implementation-focused.

2. Problem & Objectives
Create a secure, campus-scoped marketplace supporting listings, search, and 
bidding. Objectives: reliable identity (role-based), safe payments (Google 
Pay/online-banking via PSP), and actionable moderation.
3. SaaS Architecture
Rails 7 MVC on MySQL. Multi-tenant boundary at College/Hostel via scoping. 
Services: Bidding (atomic), Payments (provider strategies), Search, Notifications 
(ActionCable). Background jobs (Sidekiq) for auction close & emails.

4. Key User Stories
• As a student, I can list an item with photos and category.
• As a buyer, I can search, filter, and place bids with real-time updates.
• As the highest bidder at close, I’m prompted to pay securely.
• As a moderator, I can flag or remove inappropriate listings.
5. Advanced Features (N−1)
• External APIs: Google Pay via PSP (e.g., Stripe/Adyen) for wallet checkout.
• Real-time: ActionCable notifications for overbids and auction countdown.
• Background Jobs: Sidekiq to close auctions & send receipts.
• Search: Tokenized/fuzzy search with relevance ranking.
• Analytics: Basic dashboard (Chart.js) for listings and GMV.

6. Data Model (excerpt)
Entities: User, Category, ShoppingItem, Auction(1:1 item), Bid(*:auction), 
PaymentRecord, Community(College/Hostel). All prices in cents.

7. Security & Compliance
Use PSP-hosted/payment elements to avoid handling raw card data (low PCI 
scope). Enforce HTTPS and domain registration for Google Pay. Tokens handled 
server-to-server via provider webhooks.

8. Testing & CI
RSpec unit/service specs; Cucumber features for search, bidding, and checkout. 
Target >80% coverage (SimpleCov). GitHub Actions runs rubocop, rspec, 
cucumber on PRs.

9. Deployment
Public cloud (e.g., Render/Heroku/AWS). Separate staging and production. DB 
migrations via CI/CD. ENV secrets via Rails credentials or platform-specific 
secrets manager.

10. Process & Ownership
Agile cadence with weekly milestones. Use GitHub Projects and Issues. Maintain 
a Feature Ownership table in README to reflect primary/secondary devs.

11. Links (to be filled)
• GitHub Repository:
• Deployed App (Staging/Prod):
• Demo Video (5 minutes)