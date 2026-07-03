---
name: autotest
description: Use when someone asks to write or extend a durable Playwright e2e autotest for the frontend (e2e suite) — from a scenario description, an MR, a qa_mr report, or a shipped feature that needs regression coverage.
---

# /autotest — написать durable-автотест в `⟪ADAPT: путь к e2e-сьюте, напр. e2e/web⟫`

Пишет боевой Playwright-тест в `<frontend>/⟪ADAPT: путь к e2e-сьюте, напр. e2e/web⟫` по сценарию / MR / отчёту `qa_mr`.
**Конвенции и карта сюита — `references/autotest-conventions.md`: прочитай ПЕРЕД авторингом**,
не выводи устройство из головы.

## Вход
Сценарий («напиши автотест на ⟪ADAPT: пример флоу вашего продукта⟫»), MR/ветка с фичей, или отчёт `qa_mr`
(секция «Черновики автотестов»). Не хватает деталей флоу — спроси или сними с живой поверхности.
Продуктовый контекст фичи (что и зачем) — primer `${CLAUDE_PLUGIN_ROOT}/context/platform.md`;
специфика ключевой под-системы — `${CLAUDE_PLUGIN_ROOT}/context/⟪ADAPT: имя файла контекста ключевой фичи⟫.md`.

## Процесс

1. **Поверхность и место.** Определи папку `src/<surface>/` (есть — дополняй, нет — создай
   `{selectors,steps,<name>.spec}.ts` по образцу соседей). Работай в ветке/worktree фронт-репо
   (`⟪ADAPT: префикс e2e-веток, напр. feature-e2e⟫-<слаг>` от `origin/main`), не в `main`.
2. **Селекторы.** Собери `data-test` затронутых элементов: сверь с существующим `selectors.ts`
   поверхности, живой страницей (скилл `selectors_sync`) и кодом фронта. Generic-элементы дизайн-системы —
   правило «контейнер + роль» из конвенций. **Не выдумывать id.** Нет `data-test` у ключевого
   элемента — добавь во фронте через ⟪ADAPT: способ проставить data-test, напр. хелпер useTestId⟫
   (отдельным коммитом) или зафиксируй просьбу к фронту.
3. **Состояние (ARRANGE).** Нужен логин/деньги → фикстура `fixtures/authed.ts`
   (`test.use({ authed: true })` / `{ funded: true, fundAmount: '…' }`); гостевой →
   `@e2e/bridge-playwright`. Логин через UI — только если сам логин и есть проверяемый флоу.
4. **Шаги.** В `steps.ts` поверхности: `allure.step`-обёртки, ассерты внутри шагов, экспорт
   в `<surface>Steps`. Переиспользуй существующие шаги (в т.ч. чужих поверхностей — напр. шаги
   одной поверхности внутри спеки другой), не дублируй.
5. **Спека.** Читается как проза: только вызовы шагов, тег вьюпорта через
   `makeTestDescription('<Feature>', '<viewport>')`. Начни с `desktop`; `tablet`/`phone` —
   отдельными describe, если флоу на них отличается (другие точки входа — см. конвенции).
6. **Прогон и доводка.** Передай в скилл `autotest_run`: прогон на слоте, починка флака,
   до зелёного. Затем ⟪ADAPT: команды проверки типов + линта e2e, напр. npm run ci:type + npm run ci:eslint⟫
   из `⟪ADAPT: путь к e2e-сьюте, напр. e2e/web⟫`. **Менял код фронта**
   (напр. добавил `data-test` через ⟪ADAPT: способ проставить data-test⟫ в `⟪ADAPT: путь к приложению фронта, напр. apps/web-client⟫`) — прогони green-sequence и там
   (`⟪ADAPT: полный green-sequence фронта, напр. ci:type/ci:eslint/oxfmt/knip, из корня⟫`) и пройди **dev-check стадии 5 перед push**:
   подтверди, что элемент рендерится и `data-test` реально в DOM (проще всего — живой клик/прогон
   спеки против дев-сервера `⟪ADAPT: URL локального дев-сервера⟫`), иначе hook-гейт не пустит пуш.
7. **MR.** **Прочитай `${CLAUDE_PLUGIN_ROOT}/skills/delivery_orchestrator/references/repo-conventions.md`
   (§ Git: ветки/коммиты + § MR) ПЕРЕД оформлением — не по памяти**, там точные правила. Критично:
   ветка `⟪ADAPT: префикс e2e-веток, напр. feature-e2e-*⟫`; коммиты английские по стилю репо и **БЕЗ трейлера
   `Co-Authored-By`/`Generated with Claude Code`** (CI-джоба Code Check отклонит MR; в git-worktree хук
   `commit-msg` не executable → локально пропустит, не обманись — попал трейлер, `git commit --amend`
   + `git push --force-with-lease` своей ветки); draft-MR **предзаполненной markdown-ссылкой** (не голый
   URL/не code-блок; `Draft:`-префикс, англ. title/description, чек-лист `- [ ]`), ссылку давать
   **после** успешного пуша + пояснить, где найти MR (Code → Merge requests → Open).

## Правила

- **Сначала конвенции, потом код** — файл `references/autotest-conventions.md` обязателен к прочтению.
- Спека без локаторов и ассертов; шаги без капитанских комментариев.
- Один тест = один пользовательский сценарий целиком (не микро-шаги по одному на `test()`).
- Тест должен быть **зелёным на слоте** до передачи в MR — «написан, но не прогнан» не сдаём;
  нет доступного слота → пометь `[не прогнано: нет слота]` явно.
- Скилл не коммитит без запроса — код пишется в ветку, коммит/пуш согласуй с пользователем.
- **Коммиты во фронт-репо — без `Co-Authored-By`/`Generated with Claude Code`** (переопределяет дефолт
  Claude Code; иначе CI Code Check заворачивает MR). Правила MR — из `repo-conventions.md`, читать перед
  оформлением, не по памяти (краткая версия в `CLAUDE.md` неполна).
