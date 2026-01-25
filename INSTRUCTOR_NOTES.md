# Instructor Notes

Feedback and observations from code reviews throughout the Rails Mastery project.

---

## Day 1 - Request Lifecycle (Grade: 82)

**What was done:** Traced a request through Rails using curl and log analysis.

**Strengths:**
- Correctly identified the router → controller → action → view flow
- Good instinct to test schema_migrations behavior by restarting server
- Correctly identified `*/*` as MIME/Accept type and verified with `.json`
- Noticed the layout wrapping behavior

**Areas for improvement:**
- Rack/Puma distinction: Puma receives the TCP connection, not ActionDispatch. ActionDispatch is a collection of middleware, not a single entry point.
- Rendering order misread: Layout starts, yields to template, template completes, then layout completes. Outside-in initiation, inside-out completion.
- Migration pseudocode oversimplified: Rails raises `ActiveRecord::PendingMigrationError` with a helpful error page, doesn't silently error.

---

## Day 2 - Middleware Stack (Grade: 78)

**What was done:** Read ActionDispatch source, traced middleware stack initialization.

**Strengths:**
- Found the right files (`stack.rb`, `default_middleware_stack.rb`)
- Correctly traced from `Application` to `DefaultMiddlewareStack.build_stack`
- Ran `bin/rails middleware` and noted router is at the end (`run TestApp::Application.routes`)

**Areas for improvement:**
- Entry was brief - would have liked to see analysis of what each middleware layer does
- Didn't connect back to Day 1's request tracing through these layers
- Noted curiosity about where router fits but didn't follow up

---

## Day 3 - Active Record Internals (Grade: 75)

**What was done:** Studied connection handling, traced from `establish_connection` through connection pool.

**Strengths:**
- Good source diving into `lease_connection`, `connection_pool`, `ConnectionHandler`
- Correctly traced the `#find` → `#cached_find_by` → `with_connection` flow
- Understood that connection pooling happens at the `with_connection` level

**Areas for improvement:**
- Entry was incomplete - mentioned "struggling to find" but didn't show resolution
- Didn't cover query interface as the assignment requested
- Missing practical experiments (e.g., checking pool size, connection checkout behavior)

---

## Day 4 - Arel (Grade: 80)

**What was done:** Studied Arel, compared to Rails 2 string building, experimented with eager loading.

**Strengths:**
- Excellent historical context - found Rails 2 `construct_finder_sql` to show why Arel matters
- Good explanation of AST concept and visitor pattern
- Practical experiments with `to_sql` on joins
- Tested all four eager loading methods (joins, includes, preload, eager_load)

**Areas for improvement:**
- The eager loading experiment used `.count` which triggers additional queries - should have used `.size` or `.length` to see the preloaded data in action
- Didn't summarize the key difference: `includes` picks strategy automatically, `preload` forces separate queries, `eager_load` forces LEFT OUTER JOIN
- Missing: when to use each (preload for unrelated filtering, eager_load when filtering on association)

---

## Day 5 - Callbacks Lifecycle (Grade: 83)

**What was done:** Mapped full callback chains for create/update/destroy with practical examples.

**Strengths:**
- Comprehensive coverage of all callback types including around_* with yield
- Excellent use of `self.inspect` to show object state changes through the chain
- Correctly identified transaction boundaries (after_commit vs after_save)
- Noted that validation callbacks run on `.valid?` calls too
- Good coverage of after_initialize, after_find, after_touch

**Areas for improvement:**
- Didn't cover `throw :abort` to halt the callback chain
- Missing discussion of callback ordering when multiple callbacks of same type exist
- No mention of `prepend: true` option for callback ordering
- The destroy ordering observation ("before/after and around are inverted") isn't quite right - it's the same pattern, just fewer callbacks

---

## Day 7 - Project Model Setup (Grade: 90)

**What was built:** Project model with belongs_to Client, name, description, hourly_rate (cents), status enum. Migration with foreign key constraints. Model validations and tests.

**Strengths:**
- Correct foreign key constraint via `belongs_to :client, null: false, foreign_key: true`
- Smart choice to store hourly_rate as integer cents to avoid floating point issues - this is industry best practice (Stripe does the same)
- Modern Rails 7+ enum syntax: `enum :status, [ :active, :archived, :completed ]`
- Good validation: `numericality: { greater_than_or_equal_to: 0 }`
- Thorough tests covering association, presence, numericality, and enum behavior (including ArgumentError on invalid status)
- Correctly updated Client model with `has_many :projects, dependent: :destroy`

**Areas for improvement:**
- Consider naming the column `hourly_rate_cents` to make the unit explicit - common Rails convention used by gems like money-rails
- Index on `name` is questionable utility; a composite index on `[client_id, status]` would better serve queries like "all active projects for this client"
- Fixture uses `status: 0` instead of `status: :active` - works but less readable

**Key takeaway:** Good instinct on money handling. Storing cents as integers is the right call for a billing app.

---

## Day 6 - Client Model Setup (Grade: 89)

**What was built:** Client model with name, email, company, phone, notes fields. Migration with indexes. Model validations and tests.

**Strengths:**
- Clean migration with appropriate null constraints (name, email, company required; phone, notes optional)
- Good index choices: name and company for searching, unique index on email
- Custom email regex that's stricter than Rails' `URI::MailTo::EMAIL_REGEXP` - correctly rejects `username@com`
- Thorough email format tests with 5 invalid and 3 valid edge cases
- Pushed back correctly on instructor's suggestion to use the "battle-tested" regex

**Areas for improvement:**
- Initial version required phone/notes - needed prompting to reconsider which fields are truly required
- Initial version lacked email format validation - added after prompting
- Email uniqueness is case-sensitive; `User@Example.com` and `user@example.com` would be allowed as separate records. Consider `uniqueness: { case_sensitive: false }` or normalizing with `before_validation { email.downcase! }`
- Could add a test that a valid client saves successfully (not just that invalid ones fail)

**Key takeaway:** Think through data requirements upfront - which fields are required vs optional, what validations does the data need - before writing the first version.

---
