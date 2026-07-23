---
name: selectors_sync
description: Use when e2e selectors drift from the live frontend surface — before/after authoring autotests, when specs fail on missing data-test ids, or to inventory which elements of a surface lack unique data-test attributes.
---

# /selectors_sync — синк `data-test` с живой поверхностью

Снимает фактические `data-test` с живой поверхности на слоте, диффит с `selectors.ts` этой
поверхности в `<frontend>/⟦E2E_PATH⟧/src/<surface>/` и приводит их к согласию.
Формат id и правило generic-элементов — `../autotest/references/autotest-conventions.md`.

## Процесс

1. **Гейт:** слот отвечает (`SLOT_URL` из `.env` / авто-деплой — `../delivery_qa_smoke/SKILL.md` §2);
   devVPN включён.
2. **Снять live-инвентарь.** Открой поверхность (Playwright MCP, инкогнито; авторизация temp-кошельком,
   если поверхность за логином) и собери все id в нужном состоянии UI (открой оверлеи/меню — их
   `data-test` появляются только в DOM открытого состояния):
   ```js
   async (page) => [...new Set([...document.querySelectorAll('[data-test]')]
     .map((el) => el.getAttribute('data-test')))]
   ```
   (запускать в контексте страницы; для оверлеев — после открытия).
3. **Дифф с `selectors.ts`:**
   - id есть на странице, нет в `selectors.ts` → добавь в подходящую группу (`<смысл>TestIds`);
   - id есть в `selectors.ts`, нет на странице → проверь состояние UI (за оверлеем? фича-флаг?),
     реально удалён из фронта → пометь/убери вместе с шагами, которые на него ссылаются;
   - элемент есть, но `data-test` **generic** (`"Button"`, `"Input"` из ui-kit) → в отчёт, раздел
     «нужен уникальный `data-test`» (просьба к фронту или сразу ⟦DATA_TEST_HELPER⟧ — см. конвенции).
4. **Сверка с кодом фронта** (если репо доступно): `grep -r "⟦DATA_TEST_HELPER⟧\|data-test"` по модулю в
   `⟪ADAPT: путь к исходникам фронта, напр. apps/web-client/src⟫/` — ловит id, которые рендерятся только в редких состояниях.
5. **Выход:** обновлённый `selectors.ts` (staged, без коммита) + короткий отчёт: добавлено /
   расхождения / generic-зоны. Закрой браузер (`browser_close`).

## Правила

- **Не выдумывать id** — в `selectors.ts` попадают только id, увиденные на живой странице или в коде фронта.
- Не переименовывай существующие id «для красоты» — на них завязаны шаги и чужие тесты.
- Прогоняй затронутые спеки после правок (`autotest_run`), если менялись используемые id.
