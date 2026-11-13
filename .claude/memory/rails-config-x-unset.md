---
name: rails-config-x-unset
description: An unset Rails.configuration.x key answers nil to any reader, so a spec asserting its attributes are nil passes before the code exists
metadata:
  type: reference
---

`Rails.configuration.x.<key>` for a key nothing has set returns an empty `ActiveSupport::OrderedOptions`, not nil, and that object answers nil to any reader (`config.x.build_facts.version` is nil). A spec that asserts a boot reading's attributes are nil (spec 084, "is read at boot from nothing in the test environment") therefore passes before the initializer exists, and proves nothing.

**Why:** spec 084's T1.2 example was green before `config/initializers/build_facts.rb` was written; the implementer noticed it, and `9f38fcdc` added the class check.

**How to apply:** when a spec checks a value an initializer puts into `Rails.configuration.x` (the build facts, `public_catalog`, `default_currency`), also assert its class or a non-nil value (`expect(Collector::BuildFacts.current).to be_a(Collector::BuildFacts)`), and see it fail before the initializer exists.
