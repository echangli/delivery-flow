# Конвенции автотестов (`⟪ADAPT: путь к e2e-сьюте, напр. e2e/web⟫`) — карта и правила

Источник правды по устройству боевого Playwright-сюита `<frontend>/⟪ADAPT: путь к e2e-сьюте, напр. e2e/web⟫`. Используется скиллами
`autotest`, `selectors_sync`, `autotest_run`. Здесь — состояние **по факту репо**. Если репо разошлось
с этим файлом — прав репо, обнови файл.

> 🔧 **ADAPT — заполнить по факту вашего e2e-сюита.** Ниже раскладка слоёв, структура папок, фикстуры,
> формат id и проекты (Desktop/Tablet/Phone) — как у эталонного проекта. Пройди по своему `e2e`-каталогу
> и приведи имена файлов/папок, фикстур, env-переменных и API-эндпойнтов в соответствие с реальностью;
> общий принцип слоёв (spec → steps → selectors/fixtures) и «готовь состояние API/bridge, действуй через UI»
> — переносимый, менять не нужно.

## Слои (тест читается сверху вниз; состояние подаётся снизу вверх)

```
spec (*.spec.ts)        ← ЧТО проверяем; тег вьюпорта; читается как проза
  └─ steps (steps.ts)   ← UI-действия + ассерты, обёрнуты в allure.step   [ACT + ASSERT]
       ├─ selectors.ts  ← data-test id поверхности (источник правды)
       └─ fixtures/     ← authed / funded — подают готовое состояние      [ARRANGE]
            ├─ api/     ← бэкенд-хелперы: temp-логин, top-up              [быстрый ARRANGE]
            └─ ⟪ADAPT: bridge-пакет, напр. @e2e/bridge⟫ ← navigate, ожидание ready, feature-флаги, skipAnimation
```

**Ключевой принцип:** *готовь состояние быстрым путём (API / bridge), действуй и проверяй через UI.*

## Структура (feature-папки)

```
⟪ADAPT: путь к e2e-сьюте, напр. e2e/web⟫/src/
  shared/     describe.ts (makeTestDescription) · common.selectors.ts (кросс-поверхностное)
  api/        gateway.ts (cidHeaders) · tempAuth.ts (apiLoginTempWallet) · topUp.ts (apiTopUp)
  fixtures/   authed.ts — test с опциями authed / funded / fundAmount
  auth/       { selectors.ts, steps.ts, auth.spec.ts }
  ⟪ADAPT: ваша ключевая поверхность⟫/   { selectors.ts, steps.ts, <name>.spec.ts, … }
  settings/ … ⟪ADAPT: остальные поверхности вашего продукта⟫   — каждая поверхность самодостаточна
```

Playwright ищет `src/**/*.spec.ts` рекурсивно — при добавлении новой папки конфиг править не нужно.
Новая поверхность = новая папка `{selectors,steps,<name>.spec}.ts` по образцу соседей.

## Авторизация и деньги — фикстура, не UI-боилерплейт

- **Гостевой тест:** `import { test } from '⟪ADAPT: bridge-пакет, напр. @e2e/bridge-playwright⟫';`
- **Нужен залогиненный/пополненный юзер:** `import { test } from '../fixtures/authed';` и в describe:
  ```typescript
  test.describe(makeTestDescription('⟪ADAPT: имя вашей поверхности/флоу⟫', 'desktop'), () => {
    test.use({ fundAmount: '1000.00', funded: true }); // или { authed: true } без денег
    …
  });
  ```
  Фикстура логинится **через API** (`apiLoginTempWallet` → credentials в localStorage через
  `addInitScript`) и пополняет через `apiTopUp` (`⟪ADAPT: эндпойнт пополнения баланса, напр. POST /api/balance/top-up/v1⟫`, Bearer-токен,
  заголовки из `api/gateway.ts`). API-хост — `E2E_API_URL` (дефолт `⟪ADAPT: API-хост стейджа⟫`).
- **UI-логин** (`authSteps.loginViaTempWallet(page, joinFrom)`) остаётся только там, где сам логин —
  тестируемый флоу (`auth/*.spec.ts`); `joinFrom: 'header'` на desktop, `'nav'` на tablet/phone.

## Селекторы

- `testIdAttribute = 'data-test'` → в шагах `page.getByTestId(...)`.
- Формат id: `⟪ADAPT: схема id, напр. layer:module:component⟫`, напр. `⟪ADAPT: пример id вашего проекта⟫`.
- В `selectors.ts` — сгруппированные объекты по смыслу:
  ```typescript
  export const ⟪ADAPT: имя группы⟫TestIds = {
    amountInput: '⟪ADAPT: пример id вашего проекта⟫',
    …
  };
  ```
- **Generic `data-test` (гоча).** Кнопки/инпуты из ⟪ADAPT: пакет вашей дизайн-системы⟫ часто рендерятся с
  `data-test="Button"`/`"Input"` — **не уникальны**. Правило: опирайся на стабильный контейнер с
  уникальным id + внутри `getByRole('button', { name: 'Login' })` / `getByText`. Каждую generic-зону
  помечай «нужен уникальный `data-test`» — это постоянная просьба к фронту; добавить id самому можно
  через ⟪ADAPT: способ проставить data-test, напр. хелпер useTestId⟫ в компоненте фронта (отдельным коммитом в ту же ветку).
- **Не выдумывай id** — сверяй с живой поверхностью (скилл `selectors_sync`) или кодом фронта
  (`grep -r "data-test\|⟪ADAPT: хелпер data-test, напр. useTestId⟫" ⟪ADAPT: путь к исходникам фронта, напр. apps/web-client/src⟫/<модуль>`).

## Шаги и спеки — стиль (преференции фронтендера с ревью)

- Шаг = `async (page) => allure.step('Человекочитаемое название', …)`; экспорт группой
  `export const <surface>Steps = { … }`.
- Спеки — **без ассертов и локаторов**, только вызовы шагов; между шагами пустая строка; долгие
  сценарии — `test.setTimeout(120_000)`.
- Тег вьюпорта: `test.describe(makeTestDescription('Feature', 'desktop'), …)` → grep `@desktop`;
  проекты: `desktop` (⟪ADAPT: девайс, напр. Desktop Chrome⟫), `tablet` (⟪ADAPT: девайс, напр. iPad Pro 11⟫), `phone` (⟪ADAPT: девайс, напр. iPhone 12 Pro⟫).
- **Комментарии минимальны** — только неочевидное «почему»/гочи/маркеры `[уточняем]`; без
  капитанских, дублирующих имена шагов и Allure-лейблы.

## Запуск (детали — скилл `autotest_run`)

- Против слота: `SLOT_URL` в `⟪ADAPT: путь к e2e-сьюте, напр. e2e/web⟫/.env` (образец `example.env`; `⟪ADAPT: скрипт копирования env, напр. init:staging⟫` копирует) или в
  env команды. `E2E_DEVELOPMENT=false` = стейдж (скрипт `⟪ADAPT: скрипт UI-режима против стейджа, напр. start:staging⟫` — UI-режим).
- Точечный прогон: `SLOT_URL=https://<слот>/ npx playwright test src/<папка>/<спец>.spec.ts
  --project=desktop --reporter=line --workers=1 --retries=2` (зеркалит CI; в конфиге `retries: 0`).
- Проверки кода: `⟪ADAPT: команды проверки типов + линта, напр. npm run ci:type, npm run ci:eslint⟫` (из `⟪ADAPT: путь к e2e-сьюте, напр. e2e/web⟫`).

## Известные гочи

- `npx playwright install` может зависать на распаковке (локально) → браузеры ставить вручную
  (curl + unzip в кэш Playwright) либо гонять через e2e-CI джобы.
- Флак `page.goto` к слоту (сеть/тяжёлый `load`) — гасится `--retries=2`; не маскируй ретраями
  реальные падения ассертов.
- MR с новым `⟪ADAPT: неймспейс внутренних пакетов монорепо, напр. @shared/*⟫`-пакетом на main → в worktree нужен `npm install` (symlink), одного
  `⟪ADAPT: скрипт пересборки пакетов, напр. rebuild-packages⟫` мало.
