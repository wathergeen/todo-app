# Interface Refinements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align the Flutter interface and project documentation with explicit loading, error, empty, validation, accessibility, responsive, and retry states already implied by the Todo List flows.

**Architecture:** Preserve the current Flutter structure: views render UI, Riverpod view models own state and backend calls, services keep HTTP access, and pure board logic remains in `board_logic.dart`. UI changes stay in the existing view files and avoid new abstractions unless a small private widget keeps `board_view.dart` predictable.

**Tech Stack:** Flutter, Dart, Riverpod, Dio, `flutter_test`, Flask API contract documented in the existing spec.

---

### Task 1: Documentation Scope

**Files:**
- Modify: `especificacao_todoList.md`
- Create: `doc/testing.md`
- Modify: `testing.md`
- Modify: `README.md`

- [ ] Add a frontend interface refinement section to `especificacao_todoList.md` covering only existing login, register, board, create, move, delete, loading, error, empty, retry, timeout, validation, accessibility, and responsive behavior.
- [ ] Create `doc/testing.md` with frontend test scenarios for widget/component tests, responsive states, accessibility labels, conditional rendering, API integration boundaries, E2E manual scope, visual regression checklist, usability checks, and loading/error/fallback validation.
- [ ] Keep root `testing.md` consistent by pointing to backend and frontend testing scopes.
- [ ] Update `README.md` with the new frontend test command and the location of `doc/testing.md`.

### Task 2: Widget Tests First

**Files:**
- Create: `frontend/test/views_test.dart`
- Modify: `frontend/lib/views/login_view.dart`
- Modify: `frontend/lib/views/register_view.dart`
- Modify: `frontend/lib/views/board_view.dart`

- [ ] Write tests that assert login and register show visual validation messages before calling backend state.
- [ ] Write tests that assert board error state renders a retry action.
- [ ] Write tests that assert empty board and empty column messages render.
- [ ] Run `cd frontend && flutter test test/views_test.dart` and confirm the new tests fail for missing UI behavior.

### Task 3: Minimal UI Implementation

**Files:**
- Modify: `frontend/lib/views/login_view.dart`
- Modify: `frontend/lib/views/register_view.dart`
- Modify: `frontend/lib/views/board_view.dart`

- [ ] Convert auth and create-task fields to local `Form` validation with explicit visible messages.
- [ ] Add retry button for board load errors without existing data.
- [ ] Add empty board and empty column messages.
- [ ] Add non-blocking loading feedback when refreshing a board that already has data.
- [ ] Add basic semantic labels/tooltips for primary icon actions and drag/delete surfaces.
- [ ] Run `cd frontend && flutter test test/views_test.dart` until the new widget tests pass.

### Task 4: Full Verification

**Files:**
- No new files.

- [ ] Run `cd frontend && flutter test`.
- [ ] Run `just frontend-analyze`.
- [ ] Run `just backend-test`.
- [ ] If backend smoke is available in the current environment, run `just backend-smoke`.
- [ ] Fix any failures caused by this work and rerun the failing command.
