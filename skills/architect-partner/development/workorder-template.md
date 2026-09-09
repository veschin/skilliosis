# Work order <ID>

- lane: research | impl | experiments | benches
- date: YYYY-MM-DD
- architect: <session / agent id>
- worker: <agent type>
- bd issue: <id>
- series: <series id | single>
- depends on: <order ids | none>

## Source anchors

- TZ: <lines / sections, verbatim>
- QUOTES: [Q:<id>] ...
- CODEX: <sections>
- purpose: <the WHY - TZ line or [Q:id]>
- REF: <node ids>

## Scope (exact)

- files / dirs: <paths>
- in scope: <what exactly>
- out of scope: <explicit>

## Output

- template / format to fill: <path or inline>
- output location: <research/ | impl/ | experiments/ | benches/ path>
- vocabulary: <names locked by the order or the codex>

## Constraints (bans - verbatim in every order)

- No comments in code. A perceived need for a comment = refusal report.
- No naming beyond the order or codex vocabulary.
- No dependencies beyond CODEX.md.
- No decisions, no adjacent fixes, no architect-domain access, no commits.

## Verifier (acceptance gate)

- command: <exact command>
- expected: <exact expected outcome>

## Refusal protocol

- Blocked or underdetermined -> stop, write a refusal report: blocked / missing / options.
- Refusal report path: <research/ | impl/ | experiments/ | benches/ path>

## Completion report (worker fills)

- order id:
- produced:
- verifier output (verbatim):
- deviations: none | refusal: <path>
