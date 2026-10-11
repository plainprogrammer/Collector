# Research 016: Do Scryfall's Terms Permit a Hosted Instance?

**Status:** Findings, ruled on 2026-10-11 ([section 7](#7-the-maintainers-ruling))
**Date:** 2026-10-11
**Roadmap:** [item 1](../../roadmap.md#theme-a-data-safety), for the [north star](../../north-star.md#hosted-door-rules)'s first hosted-door rule ("source terms allow hosting")

This is a research note with no spec or plan. It reads the published terms against what Collector does today and reports. It is not legal advice: where the terms leave a question open, the note says so and doesn't settle it.

## Answer

- **A free instance, public or invite-only, is permitted,** provided the gaps in [section 4](#4-gaps-in-the-app-today) are closed. Donations and sponsorship are allowed.
- **A paid instance is permitted by Scryfall's wording only if card data stays reachable without paying.** An instance where every account is paid breaks Scryfall's guidelines outright.
- **Charging for anything at all is unsettled under Wizards of the Coast's policy,** which Scryfall's permission sits under and which is stricter than Scryfall's own wording. The documents can't settle it. It needs Wizards' written permission or legal advice before a paid plan is built.

So Scryfall passes the hosted-door rule for a free hosted service, and passes it for a paid one only with conditions and one open question.

## 1. Sources

All fetched on 2026-10-11.

| Document | Address | What it governs |
|---|---|---|
| Scryfall API documentation, "Use of Scryfall Data and Images" | `https://scryfall.com/docs/api` | The card data and images Collector ingests |
| Scryfall bulk data documentation | `https://scryfall.com/docs/api/bulk-data` | How often to download |
| Scryfall Terms of Service | `https://scryfall.com/docs/terms` | Scryfall's own site and accounts; it adds nothing on API data beyond the page above |
| Wizards of the Coast's Fan Content Policy (last updated 15 November 2017) | `https://company.wizards.com/en/legal/fancontentpolicy` | The intellectual property itself: card text, images, names |

Scryfall states that it provides the data "as part of the Wizards of the Coast Fan Content Policy", so both layers apply: Scryfall's guidelines for the data as Scryfall serves it, and Wizards' policy for the content.

## 2. What the terms say

### Scryfall: data

> You may not "paywall" access to Scryfall data. You may not require anyone to make payments, take surveys, agree to subscriptions, rate your content, join chat servers, or follow channels in exchange for access to Scryfall data. If you have an account system, end-users should be able to access card data anonymously or with free accounts.

> You may not simply repackage, republish, or proxy Scryfall data. Your software must create additional value for end-users.

Also: no use of Scryfall's name or logos that implies endorsement, and no use of the data for another game.

### Scryfall: images

> Do not cover, crop, or clip off the copyright or artist name on card images. Do not distort, skew, or stretch card images. Do not blur, sharpen, desaturate, or color-shift card images. Do not add your own watermarks, stamps, or logos to card images.

When the `art_crop` is used, the artist and copyright must be shown in the same interface.

### Wizards of the Coast: Fan Content Policy

> You can't require payments, surveys, downloads, subscriptions, or email registration to access your Fan Content; You can't sell or license your Fan Content to any third parties for any type of compensation

> You can, however, subsidize your Fan Content by taking advantage of sponsorships, ad revenue, and donations—so long as it doesn't interfere with the Community's access to your Fan Content.

It also asks for a notice that the content is unofficial:

> "[Title of your Fan Content] is unofficial Fan Content permitted under the Fan Content Policy. Not approved/endorsed by Wizards. Portions of the materials used are property of Wizards of the Coast. ©Wizards of the Coast LLC."

Wizards may withdraw permission "at any time—for any reason or no reason".

## 3. Each hosted form against the terms

| Form | Scryfall's guidelines | Wizards' policy |
|---|---|---|
| Self-hosted, for family and friends | Permitted | Permitted |
| Invite-only instance, free | Permitted | Permitted, see the registration point below |
| Free public instance, funded by the maintainer or donations | Permitted | Permitted; donations are named as allowed |
| Paid plans, with card data reachable on a free account | Permitted by the wording: "anonymously or with free accounts" | **Unsettled** |
| Every account paid | **Not permitted** | **Not permitted** |

Two points the table can't resolve:

- **What a paid plan would be selling.** A collector's lots, locations and exports are their own records, and Scryfall's wording protects access to card data only. On that reading, a free tier that includes the catalog and search, with payment for collection features or capacity, complies. Wizards' policy is broader: it says Fan Content can't be sold and can't require a subscription. Whether a collection tracker that displays card images is Fan Content being sold, or a service that happens to show it, is a question of interpretation that this note can't answer. Other collection tools charge for plans; this note hasn't checked what terms or permissions they operate under, so their existence isn't evidence.
- **Registration.** Wizards' policy says access can't require "email registration". Scryfall's guideline accepts free accounts. Collector's card search has required sign-in since spec 004, and sign-up is closed by default. The stricter reading would ask for card pages to be reachable without an account on a public instance.

## 4. Gaps in the app today

These apply to any instance, hosted or not. Each was checked in the code on 2026-10-11.

| Gap | Evidence | Which rule |
|---|---|---|
| No unofficial-content notice anywhere in the app | The only notices are "Card data and images provided by Scryfall." on the card page (`app/views/catalog/entries/show.html.erb:50`) and an attribution line in `README.md` | Wizards' policy, rule 2 |
| Attribution appears on the card page only | The collection grid, the table, search results and the scanner show card images with no attribution | Wizards' policy, rule 2; good practice under Scryfall's |
| Card images are fitted with `object-fit: cover` | `.c-tile__media img` and `.c-item__image img` (`app/assets/stylesheets/collector/components.css:88,249`) in a 63:88 box. Scryfall's images are 488×680, a ratio that differs by about 0.2%, so the clip is a fraction of a pixel in practice, but `cover` crops by design if an image's ratio ever differs | Scryfall's image guideline ("do not crop") |
| Card data needs an account | Catalog search requires sign-in (spec 004) | Wizards' policy on registration, on the stricter reading; fine under Scryfall's |

What already complies:

- **Ingestion.** Bulk data only, refreshed weekly, with a descriptive `User-Agent` (`app/models/mtg/scryfall/client.rb:7`). Scryfall's bulk page suggests weekly for gameplay data.
- **No proxying.** Pages link to Scryfall's image addresses directly; the app doesn't re-serve card images.
- **Additional value.** Collector tracks ownership; it doesn't republish the catalog.
- **No trademarks as decoration.** The design system already forbids set symbols, mana symbols and frame art in the interface.
- **The art index (spec 011).** The build downloads each artwork's `small` image once into a cache that is never served, and publishes fingerprints, not images. The fingerprint crops the art region for measurement only and displays nothing. This reading is the note's own; Scryfall's guidelines address displayed images and don't mention derived data.

## 5. Recommendation

1. **Record the rule as passed for a free hosted service and conditional for a paid one.** The north star's note on Scryfall would say: a hosted instance must keep the catalog and search reachable on a free account, and no paid plan is built until Wizards' position on charging is settled in writing or by legal advice.
2. **Add one small spec to the housekeeping lane: show the unofficial-content notice and the attribution app-wide** (a footer), and fit card images with `contain`. It closes the first three gaps and is needed by every instance, including the family one.
3. **Leave anonymous card pages to the hosted-service design.** It only matters on a public instance, and it is a hosted-service feature, which the north star places after 1.0. Record it in the parked list so it isn't lost.
4. **Treat Wizards' right to withdraw permission as a standing risk of the MTG type,** and one more reason for foundation principle 4: the app must keep working from its local copy, and a collector's own records never depend on the source.

## 6. Open questions for the maintainer

- Is recommendation 1's wording the ruling to record against the hosted-door rule?
- Should the notice-and-attribution spec (recommendation 2) be taken before theme A continues, or between specs as housekeeping?
- If a paid plan is ever wanted: ask Wizards for permission, or take legal advice? Nothing is needed before 1.0.

## 7. The maintainer's ruling

Given on 2026-10-11 and recorded in the [roadmap's decision log](../../roadmap.md#decision-log) (rulings 27–29).

- **Recommendation 1 is accepted, with an addition.** Scryfall passes the rule for a free hosted service. Any Wizards of the Coast or Scryfall data will be publicly accessible on a hosted instance: search is open to everyone, including unauthenticated visitors. No paid plan is built until Wizards' position on charging is settled.
- **Recommendation 2 is accepted** as two pieces of work: a footer notice on every page ([#34](https://github.com/plainprogrammer/Collector/issues/34)) and the image-fit fix ([#35](https://github.com/plainprogrammer/Collector/issues/35)).
- **Recommendation 3 is replaced.** Anonymous card pages aren't parked: opening search has to include the card page, because the card page holds the card's text, which is the same data. It is one housekeeping candidate, "browse the catalog without signing in".
- The third open question (permission or legal advice for a paid plan) stays open. Nothing is needed before 1.0.

