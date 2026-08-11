# Task 2 — Mobile question review

## Delivered

- Added independent `question_review` domain, API repository, and ChangeNotifier. It calls only `/reviews/questions/due`, `/reviews/{id}/check`, and `/reviews/{id}/grade`; saved-word review remains on its existing `/words/*` repository and view model.
- Added `/question-review`, live due count on the review selection card, and a 10-item server-limited review session.
- Implemented MCQ, cloze, and reorder inputs; loading, empty, checking, feedback, grade retry, error, and completion states.
- Wrong checks grade automatically with rating 1. Correct checks offer ratings 2–4. Grade retries retain the answer, rating, expected reps, and operation UUID.
- Completion presents correct/incorrect totals and accumulated XP/coins, plus `Ôn thêm` when the server reports more due questions.
- Extracted `ExerciseAnswerInput` and switched Lesson to it without changing vocabulary review behavior.
- Feedback is the only state that renders correct answer/explanation; its localized live semantic region receives focus.

## Files

- `src/mobile/lib/features/question_review/domain/question_review_models.dart`
- `src/mobile/lib/features/question_review/data/question_review_repository.dart`
- `src/mobile/lib/features/question_review/presentation/question_review_view_model.dart`
- `src/mobile/lib/features/question_review/presentation/question_review_screen.dart`
- `src/mobile/lib/widgets/exercise_answer_input.dart`
- Router, provider wiring, review selection count, Lesson integration, and EN/VI translations.
- `src/mobile/test/features/question_review/question_review_flow_test.dart`

## TDD evidence

1. RED: created `question_review_flow_test.dart` before production files. `flutter test test/features/question_review/question_review_flow_test.dart --reporter expanded` failed because all four `features/question_review/*` imports did not exist.
2. GREEN: implemented the smallest separate domain/repository/view-model/UI path. The same focused test passed 5/5, then 6/6 after adding the API-path contract test.
3. Refactor: extracted the common answer component only after the question-review tests were green; re-ran Lesson and saved-word review regression tests.

## Verification

- `flutter analyze` — no issues.
- Focused Flutter suite — 17 tests passed: question review (6), Lesson flow, review integration, review selection, and vocabulary review screen.
- `git diff --check` — clean.

## Self-review

- Confirmed the repository fixture asserts bearer auth, the exact `/reviews/*` URLs, check payload, and grade snapshot (`rating`, `operationId`, `expectedReps`, `answer`).
- Confirmed a wrong response creates exactly one automatic rating-1 grade and only advances after feedback.
- Confirmed duplicate check is blocked while checking and grade retry preserves its UUID and originally selected rating.
- Confirmed correct answer and explanation do not render before check; accessibility text is localized and focus is requested on feedback.
- Confirmed no backend files or `pubspec.yaml`/`pubspec.lock` were modified.

## Concerns

- Focused widget/unit coverage is green, but this task did not run a live authenticated Flutter-to-backend/device session. That remains the appropriate next validation for backend availability, auth expiry, and screen-reader behavior on a physical device.

---

## Fix round 1 — review findings

### Delivered

- Stale question responses (`404`, `review_not_due`, `review_already_graded`) from check or grade now force a fresh due-queue load instead of leaving the learner in a retry loop.
- The question selection badge has its own EN/VI wording and awaits `/question-review` returning before it reloads the server due count.
- Reorder selection uses option indices, so duplicate tokens are independently selectable and keyed uniquely.
- Load failures show neutral copy; only a failed answer/check/grade operation promises that the answer remains available for retry.
- The selection badge layout now constrains long localized counts without a horizontal overflow.

### TDD evidence

1. **RED:** Added stale check/grade, grade double-submit, duplicate reorder, neutral load-error, feedback semantic/focus, and HTTP-method assertions to `question_review_flow_test.dart`. The focused test failed on stale reload (`fetchCalls` remained 1), duplicate `answer_reorder_had` keys, and absent neutral load text.
2. **GREEN:** Added forced stale reload that preserves already-earned session rewards, index-based reorder selections, operation-aware error copy, POST assertions, and focus/live-region assertions. `question_review_flow_test.dart` passed 13 tests.
3. **RED:** Added ReviewScreen route-return test expecting `3 câu hỏi cần ôn`, then a fresh `1 câu hỏi cần ôn` after pop. It failed because the card rendered the saved-word wording.
4. **GREEN:** Added `question_due_badge`, awaited child-route completion, reloaded the question VM, and constrained the badge. `review_screen_test.dart` passed 2 tests.

### Verification

- Focused suite passed **25 tests**: question review, Lesson flow, review integration, review selection, and vocabulary review.
- `flutter analyze` — no issues.
- `git diff --check` — clean.

### Self-review

- Confirmed stale recovery is limited to the documented stale-card cases; ordinary network errors remain retryable and preserve answer/operation ID.
- Confirmed grade remains single-flight and retry retains the original rating, expected reps, answer, and operation ID.
- Confirmed duplicate reorder tokens produce `had had`; the existing Lesson flow regression remains green.
- Confirmed feedback remains absent before checking; once shown it has a localized live semantic region and receives focus.
- Confirmed vocabulary remains on `ReviewRepository`/`ReviewViewModel` and `/words/*`.

### Remaining concern

- No live authenticated backend/device or physical screen-reader validation was run in this scoped fix; local Flutter unit/widget evidence is green.
