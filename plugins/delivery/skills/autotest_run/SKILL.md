---
name: autotest_run
description: Use when running frontend e2e Playwright specs against a stage slot or fixing failing/flaky ones — run by spec/project/tag, parse failures, repair waits and locators, rerun to green, or trigger the e2e CI jobs instead.
---

# /autotest_run — прогнать и довести до зелёного

Прогон спек из `<frontend>/⟪ADAPT: путь к e2e-сьюте, напр. e2e/web⟫` против слота стейджа + починка падений.
Карта сюита и env — `../autotest/references/autotest-conventions.md`.

## Гейт

devVPN включён; слот отвечает (`curl -sS -o /dev/null -w "%{http_code}" "$SLOT_URL"` с таймаутом).
`SLOT_URL`: `.env` рабочей папки / `⟪ADAPT: путь к e2e-сьюте, напр. e2e/web⟫/.env` (`⟪ADAPT: скрипт копирования env, напр. init:staging⟫` копирует `example.env`) /
авто-деплой временного стейджа по MR — `../delivery_qa_smoke/SKILL.md` §2. Слот не отвечает →
попроси VPN/слот и не «висни».

## Прогон

Из `<frontend>/⟪ADAPT: путь к e2e-сьюте, напр. e2e/web⟫` (или worktree ветки):

```bash
# точечный spec, зеркалит CI
SLOT_URL=https://<слот>/ npx playwright test src/<surface>/<name>.spec.ts \
  --project=desktop --reporter=line --workers=1 --retries=2
# все вьюпорты: --project=desktop --project=tablet --project=phone
# вся сьюта в UI-режиме: SLOT_URL=… npm run start:staging
```

- Прогоняй **батчем и молча**: запустил → разобрал результат → ответ в чат по завершении,
  не по одному тесту.
- Альтернатива локальному прогону — **manual e2e-CI джобы MR** (`⟪ADAPT: имена manual e2e-джоб,
  напр. End To End Desktop/Tablet/Phone Stage Slot⟫`) через GitLab API: `../delivery_qa_smoke/SKILL.md` §3.
  Предпочтительна, когда локальные браузеры не стоят или нужен полный регресс.

## Починка падений

1. **Классифицируй по выводу/трейсу** (`trace: on-first-retry`, скриншот при падении):
   селектор не найден / таймаут ожидания / реальный ассерт / инфра (сеть, слот).
2. **Селектор не найден** → сверь с живой поверхностью (скилл `selectors_sync`): id переименован,
   элемент за оверлеем/фича-флагом, generic-зона.
3. **Таймаут/флак** → чини **ожидания и локаторы** (web-first assertions `expect(...).toBeVisible()`,
   `waitFor`, ожидание состояния после действия), **не** `waitForTimeout`-слипы. Известный флак
   `page.goto` к слоту гасится `--retries=2`.
4. **Реальный ассерт упал** → возможно, нашёл баг фронта: **не подгоняй тест под поведение** —
   зафиксируй находку пользователю (дальше — как баг, Трек B).
5. Перепрогон **только упавших** до зелёного; итог: что чинилось, что осталось красным и почему.

## Правила

- Чини тест, не продукт: продуктовый код в рамках прогона не менять (исключение — ⟪ADAPT: способ проставить data-test, напр. useTestId⟫
  для отсутствующего `data-test`, отдельным коммитом).
- Ретраи маскируют только сетевой флак — ассертные падения разбирай, а не перезапускай.
- Не выдумывай результаты: прогона не было (нет слота/браузеров) → `[не прогнано: причина]`.
- В конце — краткая сводка: N passed / M failed / что сделано; Allure — `⟪ADAPT: скрипт генерации отчёта, напр. npm run ci:generate-report⟫`
  по запросу.
