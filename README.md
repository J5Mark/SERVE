# Serve - Community Business Platform

## Overview

**Serve** is a community-driven platform that connects entrepreneurs, businesses, and individuals within shared interest communities. It facilitates business discovery, collaboration, and networking through a trust-based system with community voting and verification.

## Purpose

The platform solves the problem of **B2B discovery and trust** in niche communities. Instead of cold outreach, users can:

1. **Discover** relevant businesses within their communities
2. **Validate** opportunities through collective voting ("would you pay for this?")
3. **Connect** with verified businesses ranked by relevance to their needs

## Key Concepts

### Communities
Interest-based groups (e.g., "SaaS Founders", "Local Restaurants", "Freelance Designers"). Communities can optionally link to Reddit for extended discussion.

### Businesses
User-owned business profiles with:
- Bio/description (used for AI-powered matching)
- Community associations
- Contact goals (what kind of connections they seek)
- Response time commitments
- Verification stats (seen/used/coop)

### Posts & Voting
Users post business ideas or requests to communities. Others vote with:
- **Would-pay**: The actual dollar amount they'd pay for the solution
- **Competition**: Known existing alternatives
- **Problems**: Pain points with existing solutions

### Contact Discovery (The Ranking System)
When a business user needs to find relevant contacts, the system ranks candidates by:
1. **Keyword relevance**: Matching bio/contents keywords between requester and candidates
2. **Community boost**: Higher score if candidate is in same community
3. **Verification score**: Weighted sum of verifications (coop ×3 + used ×2 + seen)

This creates a relevance-sorted list of potential partners/suppliers.

### Trust & Verification
Users can verify businesses they've:
- **Seen**: Just aware of
- **Used**: Been a customer
- **Coop**: Collaborated with

## Tech Stack

| Component             | Technology                            |
|-----------------------|---------------------------------------|
| Mobile App            | Flutter (Dart)                        |
| Backend API           | FastAPI (Python 3.13+)                |
| Database              | PostgreSQL + pgvector                 |
| ORM                   | SQLAlchemy 2.0 + asyncpg              |
| Auth                  | JWT, Google OAuth, device-based login |
| External Integrations | Reddit API                            |

## Potential Use Cases

1. **Startup Validation** - Post a startup idea to a community, get honest feedback on willingness to pay
2. **B2B Lead Generation** - Businesses find relevant partners/suppliers within their industries
3. **Freelancer Discovery** - Clients find freelancers in their local or interest-based communities
4. **Local Business Networking** - Neighborhood communities connect local service providers
5. **Vendor Discovery** - Community-recommended vendors with verification system
6. **Community Needs Satisfaction** - Communities can signal their actual needs
