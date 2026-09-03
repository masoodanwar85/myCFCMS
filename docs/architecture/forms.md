# Forms

Author-defined forms: a registration, a booking request, a survey. The other
half of the split that shrank Contact back to one enquiry form.

## Why it is a separate module

`contact_forms` was plural in the database and singular in practice for a long
time — `/contact` served one form and a second had no way to be reached. The
temptation was to finish that: give Contact a field builder and let it be many
forms. Two things argued against it.

A contact form and a survey are not the same object wearing different hats. The
enquiry form has fixed fields for a reason: a site's way of being contacted
should not be something an author can accidentally break by deleting the email
field. And every site has exactly one, which is what lets `/contact` mean
something without a picker.

So Contact stayed small and this module took the general case. It depends on
Core alone and knows nothing of Contact.

## No URLs

A form is published by a shortcode and nothing else:

    [form slug="registration"]

There are no routes. A form belongs under the copy that explains it, and a
second address for the same thing is a second thing to keep in step. The module
registers a `ContentResolver` purely to receive the POST — its `resolveContent`
returns null for every path.

(That method cannot simply be omitted: `ContentResolverRegistry.resolve()` calls
it on every registered resolver without checking it exists, while
`resolveSubmission()` guards with `structKeyExists` first. Rather than change
Core to suit one module, the method is declared and says why.)

## Three tables

| | |
|---|---|
| `forms` | The form and its settings. Unique by slug within a site, so a shortcode names exactly one thing. |
| `form_fields` | Ordered, typed field definitions. A real table because fields are individually edited and validated against on every submission. |
| `form_submissions` | One row per response, with the answers as a JSON document. |

`uq_forms_id_site` exists to be the target of composite foreign keys from the
other two — the same device `users` and `roles` use, so a field or a response
cannot be attached to another site's form even if an id were guessed.

## Answers are a snapshot, not a join

`form_submissions.answers` is a JSON array of `{ key, label, type, value }` —
the question as it was asked, beside the answer. **Not** rows keyed by
`field_id`, and this is the more important of the two storage decisions.

A response is a record of what was actually asked. Keyed by `field_id`,
renaming a field rewrites history: an answer given under "Your budget" starts
displaying under "Project value". Deleting a field either orphans its answers or
cascades them away. Neither is acceptable for something a client may need to
produce months later.

It also keeps reading one response to a single row, which is how the admin reads
them — one at a time, in full.

The cost is that answers cannot be filtered in SQL. Nothing asks to; the day
something does, this is JSON in MySQL 8 and can be indexed with a generated
column without moving the data.

Stored as `MEDIUMTEXT` rather than MySQL's `JSON` type. This project is
developed on ColdFusion 2025 and deployed on 2023, and the JDBC binding of a
string into a `JSON` column is exactly the kind of engine-specific behaviour
that has already cost this codebase a production outage.

## Field types

`FieldTypes` is one component answering three questions the rest of the module
keeps asking: is this a real type, does it take options, how is a value of it
validated. Scattering that across the builder, the validator and the renderer is
how the three drift apart — a type added to the dropdown but not the validator
is a field that accepts anything.

    text  textarea  email  tel  number  date  select  radio  checkbox

Deliberately code, not a table: each type needs a matching branch in the
renderer and the validator, so one nobody has written those for cannot usefully
be added at runtime. A spec asserts every listed type is valid and renderable.

**File uploads are absent on purpose.** They need storage quotas, type sniffing,
a retention policy and a way to serve the result safely — all of which the media
library solves for a *logged-in* user and none of which is solved for an
anonymous one.

## The builder

Fields are a **list**, one row per field: order, label, key, type and whether it
is required, all readable without opening anything. A row opens in place to
edit. They used to render as a stack of open editors, so a form with a dozen
fields was twelve full forms down the page and finding one meant scrolling past
the rest.

`<details>` rather than script — it works with the keyboard for free, and
find-in-page still reaches a closed row.

Adding a field offers **the same inputs as editing one**. It previously offered
type, label and name only, so a placeholder or a piece of help text could not be
set until after the field existed: an author had to add a field and then reopen
it to finish it. Max length is exposed in both, having been supported by the
service and reachable from neither.

A field whose type has no choices keeps its `optionsText` through a hidden
input, so switching a dropdown to text and back does not lose what was typed.

## A field's name is fixed

`field_key` is what appears in the posted data and in every stored answer.
`updateField` has no `fieldKey` argument at all, rather than accepting one and
ignoring it: changing it would file every response already given under a name
the form no longer has.

The **label** is free to change at any time. Old responses keep the label they
were given; new ones get the new one. That is the snapshot doing its job.

## Validation

Per field, driven by data an author wrote. Required-ness, length, and a check
per type — an email that looks like an address, a number that is a number, a
date that is a date.

Choice fields get the one that matters: **a posted answer must be one the form
offered.** The options are in the page source and a posted value is whatever the
sender says it is. Without that check a `select` accepts anything at all.

Answers are sanitised on the way in, unlike page content. Nothing here is meant
to be markup, and an answer is displayed in the admin and in an email a person
opens.

## The round trip

The same shape Contact uses, because it was built for exactly this problem: an
embedded form posts back to the page it sits on, and that page belongs to Pages.

    POST /some-page  ->  FormContentResolver claims it (marker names an active form)
                     ->  redirect, outcome in flash
    GET  /some-page  ->  shortcode reads flash, renders message or errors

The marker field is `cmsForm`, deliberately distinct from Contact's `form`: a
page may carry both, and two modules reading the same key from one POST would
both try to claim it.

Flash is keyed by form slug, so two forms on one page cannot show each other's
message, and it is read exactly once — a success message surviving into the next
page view would tell a visitor they had sent something they had not. Only the
form's own fields are flashed back; the CSRF token and the reCAPTCHA response
have no business in the session.

Both outcomes redirect, which also means a refused response cannot be re-posted
by refreshing.

## Rendering

Through the site's theme when it supplies a `form` view, and through Core's own
otherwise. The fallback is the *normal* case here, not the exception: a theme
written before a form existed cannot have a view for it, and that must not mean
a blank page.

Core's `_field.cfm` renders one field of any type — nine input types written
inline would be nine places to forget an escape, and a tenth type would mean
editing every theme that ever copied it. Radio and checkbox groups get a
`<fieldset>` and `<legend>` rather than a `<label for>`, which is what tells a
screen reader the options belong together.

Attribute values use `xmlFormat`, not `encodeForHTMLAttribute`. Both are safe in
a quoted attribute; the aggressive one turns every space into `&#x20;`, which
renders correctly and makes the page source unreadable. Same call as the SEO
meta tags.

## Settings worth knowing

| | |
|---|---|
| `sendNotifications` | **False by default.** A CMS that starts emailing the moment it is installed emails the wrong people. Core's `mailMode` gates it a second time. |
| `maxPerHourPerAddress` | Responses per hour from one address, 20 by default. `0` switches it off. |
| `storeSubmissions` | Per form. Untick for a form that should only send an email — still validated, still delivered, leaves no row. Existing responses are not removed by unticking it. |
| `thankYouPath` | Optional. Blank means the success message replaces the form in place. Set it when advertising conversion tracking needs a real page load. Site-relative only. |

## What is implemented

- `forms`, `form_fields`, `form_submissions` with composite tenant keys.
- Nine field types, with a builder and a per-type validator that agree by
  construction.
- `[form]`, the only way a form is published.
- A responses inbox with status triage, filtered by form and by status.
- Three permissions, separating reading responses from building forms.
- 61 specs across the module.

## What is intentionally postponed

| Area | Why it waits |
| --- | --- |
| File uploads | Quotas, type sniffing, retention and safe serving — a group of its own. |
| Conditional fields | "Show this only if that was answered X" needs a rule model and a client-side evaluator that agrees with the server's. |
| Drag-and-drop field order | `sort_order` is an editable number and the list respects it; a UI on top is presentation. |
| Export to CSV | Straightforward, but the answer shape varies per form, so the column set is a real design question. |
| Multi-page forms | Needs partial state between requests, which is a different persistence problem. |
