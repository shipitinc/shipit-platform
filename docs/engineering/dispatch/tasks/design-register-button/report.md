# Report — Independent Design Review, Register Button (`design/register-button`)

Persisted per `aef-orchestrator` §14. Reviewer: `design-reviewer`, read-only.
Worktree `/private/tmp/shipit-design-register`, branch `design/register-button`.
REVIEWED_HEAD `2922fef14680510294b056e…` (base; artifacts untracked at review time).
REVISION_ID `18A97195-B9CC-4AC3-A57B-6A1CF08F06B9`.

```
RESULT: DESIGN_REVIEW_HUMAN_DECISION_REQUIRED
CORRECTION_REQUIRED: NO
HUMAN_DECISION_REQUIRED: YES
HUMAN_DECISION_TYPE: DESIGN
INDEPENDENT_RISK_LEVEL: 2
RISK_LEVEL_AGREEMENT: YES
```

## Load-bearing claims — CONFIRMED

**F1 — `canRegister` is the constant `false`.** CONFIRMED decisively. The only `accessStatus:`
assignment in the repository is `add_product_page.dart:118` → `notChecked` (`:190` is a constructor
default, `:223` a `copyWith` preserve). Repo-wide, including `apps/control_plane/test`, **nothing**
assigns `.verified`, `.checking` or `.failed`. `canRegister` (`:233-236`) can never be true, for any
user, in any environment. The "user error" framing of the reported defect is wrong.

**F2 — `deployKey` can never be created (bootstrap deadlock).** CONFIRMED, every link.
`CheckAccessRequested` is constructed only at `:567` and `:1065`, both inside `_buildKeyBox`
(`:495`, `:994`), which is called only at `:444`/`:851` under `if (state.deployKey != null)`.
`deployKey` is set only at `:117`, `:189`, `:222`. `canGenerateKey` (`:230`) has **zero** call
sites (one occurrence in the whole repo — its own declaration). So `deployKey ≡ null`, and
`_onRegisterProductRequested`'s guard (`:149-153`) no-ops. **The gating decision is not the
operative question until the key-generation affordance is wired.**

**F4/F5/F6 — CONFIRMED.** Desktop nests the reason inside `FilledButton.child` (`:692-717`,
`inkPrimary` `:713`, gap 2 `:708`); mobile renders a sibling (`:912-920`). `errorText` keys on
`errorMessage != null` (`:421-423`, `:826-829`) while `:255-263` short-circuits to a full-page error
state — unreachable. 26 test files exist and **zero** import `add_product_page.dart`; nothing
references `AddProductBloc`, `canRegister` or `_registerButtonSubtext`.

## Blockers a design correction must clear BEFORE the human is asked

**B1 — D2's founding premise is false.** Revision:308 claims "the convention does not exist. No form
in the repository marks requiredness." Refuted: `create_defect_page.dart:458,477,495,504` carry an
in-label `(OPTIONAL)` suffix, absence-of-suffix marks required, matching the submit gate at
`create_defect_bloc.dart:201,207,216,229,238`. D2 would introduce a second, conflicting convention
— the opposite of the requirement it serves.

**B2 — D2's coverage is half the real surface and will not compile as specified.** "~8 existing
call sites" — there are **15** `FormFieldSlot(` invocations (add_product_page ×2, create_defect_page
×10, create_feature_request_page ×3, form_primitives:304). Five required defect-form fields are
unclassified. `DesignTextField` (form_primitives:287), used by `model_executions_page.dart:851,857,863`,
has no marker. With a non-defaulted `requirement`, each site forces a decision — and
`model_executions_page.dart` breaks at compile.

**B3 — D1's table decides the escalated question while claiming not to.** Rows 6-10 map `notChecked`
→ disabled and only `verified` → none, i.e. Option (a′). The note gives the transform for
keep-verified only; the recommended outcome is asserted in prose, never in the normative table. **If
the human ratifies "generated" and the implementer follows the table, the button stays disabled and
the reported defect reproduces.**

**B4 — the deploy key is a mock.** `_generateMockKeyPair` (`:126-138`) builds
`ssh-ed25519 <base64 of 32 random bytes> shipit+<name>` — not an installable key. D5 nonetheless
specifies the only reachable Key Help as "Add this key to the repository's deploy keys with write
access, then check", which is an impossible instruction.

**B5 — D1 row 6's nextAction is a control that cannot succeed**, which D1's own doc comment forbids.

**B6 — "Check access" silently rotates the key the user just copied.** Each press regenerates the
pair (`:113-120`) while "Copy public key" (`:558`) copies the current one. D1 makes that control the
designated remedy, so the prescribed path orphans the key the user just installed.

**H1 — the a11y contrast justification is numerically false.** Revision:284-287 claims `inkTertiary`
on `palette.card` is "≈6.0:1 in dark … above the 4.5:1 AA threshold". Measured from
`design_tokens.dart:96,101,117,122`: light **4.99:1**, dark **4.23:1** — **fails AA**. (The 6.0
figure matches `inkSecondary`; the tokens were confused.) The fix direction is right — today's
`inkPrimary` on the button fill is **2.72:1** dark — but `inkSecondary` (6.74:1 light / 6.10:1 dark)
must be specified instead.

**H2/H3** — desktop gap unspecified while button height changes; SC-05's verification is vacuous
(both call sites already share one `_registerButtonSubtext`, so the test passes before any change).

## Escalation judgement — the recommendation survives

Option (c)'s core argument holds: `_onRegisterProductRequested` (`:149-153`) guards only
`productName`, `repository` and `deployKey != null` — it does **not** check `verified`, so the UI
over-claims against the domain. The governance boundary is baseline approval (`:670`), not
registration (`:410`). Relaxing the UI gate does **not** let a product register without a key.
Overriding four boards remains a design-system-owner decision and is correctly escalated.

## Reviewer's sequencing conclusion (the important outcome)

`HUMAN_DECISION_REQUIRED` rather than `CHANGES_REQUIRED` because D6 is a genuine product judgement.
But: **a design correction lane must land first.** As written, the DCR asks the human to ratify an
option whose normative table implements the opposite one, and omits that the deploy key is a mock.
If the human answers "generated", the current table still yields a disabled button and the reported
defect survives.

## Traceability gaps

1. D2 → REQ-RB-004 untraceable as designed (premise false, coverage ~half).
2. The REQ-RB-003 gap is understated: unregistrable **because** the key is a mock and verification
   has no implementation — not "until Stage 2" in any implementable sense.
3. Orphan: the mock deploy key — owned by no element, traced to no AC/SC.
4. Orphan: Step 1/2 `isDone` derivation — traced to no element. Under option (c) step 2 can never
   show done, so the panel perpetually promises verification that never happens.
5. `INTAKE CATEGORY`, `EVIDENCE`, `REPRODUCTION STEPS`, `AFFECTED WORK ITEM` optionality fall
   outside D2's traceable set.
6. `model_executions_page.dart` is in neither D2's table nor the non-goals, yet breaks at compile.

## Self-assessed scores the reviewer contradicted

`DESIGN_SYSTEM_COMPLIANCE: PASS` and `UX_ACCESSIBILITY_SCORE: PASS` are both contradicted: a
convention conflicting with an existing one is not "additive", and a token failing AA in dark is
not compliant. The Penpot board-fidelity portion is **unverified** (no Penpot MCP in the review lane).
The positive part verified: every named primitive exists (`FormFieldSlot`, `formBoxDecoration`,
`SingleLineInput`, `FormSelect`, `FieldPair`, `FormSectionTitle`, `inkTertiary`, and the
`liveRegion` precedent at `state_views.dart:88-89`), with no name collision.

**M8 — the deterministic baseline was never executed.** `flutter analyze` in the review worktree
returns 8090 issues, all `undefined_identifier` on Flutter symbols, because
`apps/control_plane/.dart_tool/package_config.json` does not exist — package resolution, not a real
failure. `implementation_feasibility: HIGH` is therefore unproven, and the design's assertions that
"the existing suite is green" carry no recorded run.

## Reviewer's parallel-safety guidance

- **Blocked pending human:** D6 and D1's resolver rows 6-10.
- **Can proceed in parallel:** D2 re-grounded on the existing `(OPTIONAL)` convention with all 15
  call sites classified; D3 plus the FM-6 limitation note; D4 (required by every option); D5 copy
  corrections so no reachable copy instructs an impossible action, the key-rotation warning, the
  `isDone` re-derivation, and a test asserting no trust control renders.
- **Implementation file estimate is wrong:** D1/D3/D4/D5 are implementable in 2 files, but D2 touches
  four plus `model_executions_page.dart` compile impact.
