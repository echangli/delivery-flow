# cdp-recipes — raw-CDP к WebView приложения

Приложение — WebView-обёртка над web-client. Чтобы читать/драйвить страницу (DOM, JS, сессию, консоль,
JS-бридж) — подключаешь **сырой Chrome DevTools Protocol** к таргету-странице WebView.

**Почему сырой CDP, не Playwright:** `playwright.connectOverCDP` падает на новом WebView приложения
(Chrome ≥150: `Browser context management is not supported`). Ходи прямо к странице по websocket через
`Runtime.evaluate` / `Page.*`. На старом WebView (эмулятор API 26/27, Chromium 58/61) CDP цепляется, но
SPA не стартует — путь прямого `am start` см. в `native-checks-matrix.md`.

Метки `⟪ADAPT⟫` ниже — единственные проектные значения, замени под своё приложение.

## 0. Подключение (найти сокет → форвард → запуск)

Debug-сборка открывает `@webview_devtools_remote_<pid>`. PID (а значит сокет) **меняется при каждом
рестарте приложения** — всегда пере-резолви перед использованием.

```bash
D=<device-id>                                  # adb -s <id>; ⟪ADAPT: реальный девайс или emulator-5554⟫
sock=$(adb -s $D shell "cat /proc/net/unix" 2>/dev/null | grep -io "webview_devtools_remote_[0-9]*" | head -1)
adb -s $D forward --remove tcp:9222 2>/dev/null
adb -s $D forward tcp:9222 localabstract:$sock
curl -s http://127.0.0.1:9222/json/list | python3 -c "import json,sys;print([p['url'][:60] for p in json.load(sys.stdin)])"
```

CDP-скрипты гоняй как ESM `.mjs`. **ESM резолвит пакеты от каталога самого файла**, поэтому клади
временный скрипт внутрь фронт-проекта e2e (там уже есть `ws` и `viem`): `⟪ADAPT: <frontend>/e2e/web⟫`.
Временный файл удаляй после. `Date.now()`/`Math.random()` тут допустимы (обычный node, не workflow).

## 1. Минимальный CDP-клиент (переиспользуется каждым рецептом)

```js
import WebSocket from 'ws';
const pages = await (await fetch('http://127.0.0.1:9222/json/list')).json();
const pg = pages.find(p => p.url.includes('⟪ADAPT: stage-хост, напр. stage0.example⟫') && p.webSocketDebuggerUrl);
const ws = new WebSocket(pg.webSocketDebuggerUrl);
let id = 0; const pend = new Map();
const send = (m, p = {}) => new Promise((r, j) => { const i = ++id; pend.set(i, { r, j }); ws.send(JSON.stringify({ id: i, method: m, params: p })); });
ws.on('message', d => { const m = JSON.parse(d); if (m.id && pend.has(m.id)) { const { r, j } = pend.get(m.id); pend.delete(m.id); m.error ? j(new Error(JSON.stringify(m.error))) : r(m.result); } });
await new Promise((r, j) => { ws.on('open', r); ws.on('error', j); });
await send('Runtime.enable');
```

## 2. Runtime eval (DOM / роут / консоль)

```js
const r = await send('Runtime.evaluate', { expression: `(function(){ return { path: location.pathname, txt: (document.body.innerText||'').slice(0,80) }; })()`, returnByValue: true });
console.log(JSON.stringify(r.result.value));
```

Маркер-«переживёт ли reload» — доказывает, перезагрузилась ли страница: поставь `window.__m = 'x'`, после
действия прочитай `String(window.__m)`; `null` = JS-контекст был уничтожен (страница перезагрузилась).

## 3. Bridge call (нативные методы, которые может попросить страница)

Нативный объект-инъекция — `⟪ADAPT: appMethodRunner⟫`. Вызывай ровно как страница — это по-настоящему
задействует `onShowFileChooser`/main-thread dispatch и т.д. `execute` → boolean (принято);
`executeWithResult` → JSON-конверт `{type:'ok'|'error', data}`.

```js
const call = async (fn, method, params = {}) => (await send('Runtime.evaluate', {
  expression: `(function(){try{return {ret: String(appMethodRunner.${fn}(${JSON.stringify(method)}, ${JSON.stringify(JSON.stringify(params))}))};}catch(e){return {err:String(e)}}})()`,
  returnByValue: true,
})).result.value;
// fire-and-forget: await call('execute', 'open-share-dialog', { text_to_share: 'x' })
// запрос/ответ:     await call('executeWithResult', 'encrypted_storage_get', { name: '<key>' })
// НИКОГДА не печатай расшифрованные секреты — проверяй только type==='ok' и длину.
```

## 4. temp-wallet mint + инъекция (логин без ввода)

Минтишь одноразовую сессию через API и засеваешь в хранилище WebView. Рецепт зеркалит temp-wallet
фикстуру фронт-e2e. `⟪ADAPT⟫`: API-хост, cid-заголовки, ключ хранилища кред, ручки challenge/validate.

```js
import { generatePrivateKey, privateKeyToAccount } from 'viem/accounts';
const API = '⟪ADAPT: https://api-stage.example⟫', KEY = '⟪ADAPT: shared::feature/auth/repo/creds-inf@v1.0.0⟫';
const H = { Accept: 'application/json', 'Content-Type': 'application/json', /* ⟪ADAPT: X-CID-* заголовки⟫ */ };
const post = async (u, d) => { const r = await fetch(u, { method: 'POST', headers: H, body: JSON.stringify(d) }); if (!r.ok) throw new Error(u + ' ' + r.status); return r.json(); };
const acc = privateKeyToAccount(generatePrivateKey());
const ch = await post(`${API}/api/wallet-connect/challenge/v1`, { address: acc.address });
const sig = await acc.signMessage({ message: ch.challenge_id });
const v = await post(`${API}/api/wallet-connect/validate/v1`, { address: acc.address, challenge_id: ch.challenge_id, signature: sig, /* ⟪ADAPT: пустые appsflyer/device-поля, device_timezone⟫ */ });
const now = Date.now();
const cred = { accessToken: v.token.access, createdAt: now, expiredAt: now + v.token.recommended_refresh_token_in * 1000, keep: 'always', method: v.method, mode: 'cookie', provider: { address: acc.address, name: 'Temp Wallet', type: 'web3' }, refreshToken: null, userId: v.user_id };
await send('Runtime.evaluate', { expression: `window.localStorage.setItem(${JSON.stringify(KEY)}, ${JSON.stringify(JSON.stringify({ credentials: { ea: null, v: cred } }))})`, returnByValue: true });
await send('Page.enable'); await send('Page.reload', {});
console.log('USER_ID=' + v.user_id);   // отдай id пользователю, если проверке нужно состояние аккаунта (KYC и т.п.)
```

**Сессия — cookie-mode.** Инъекция ключа кред в localStorage логинит *свежий* WebView, но НЕ перебивает
существующую cookie-сессию (соц-логин держится нативно). Чтобы сменить юзера — сперва `pm clear`.

## 5. Форсировать сетевую загрузку документа (обойти HTTP-кэш / ServiceWorker)

Обычный reload может отдать документ из кэша (ServiceWorker'а обычно нет — проверь). Чтобы верхний
документ пошёл по сети (напр. чтобы прокси подменил статус):

```js
await send('Runtime.evaluate', { expression: `(async()=>{try{const rs=await navigator.serviceWorker.getRegistrations();await Promise.all(rs.map(x=>x.unregister()));}catch(e){}try{const ks=await caches.keys();await Promise.all(ks.map(k=>caches.delete(k)));}catch(e){}})()`, awaitPromise: true, returnByValue: true });
await send('Page.enable'); await send('Page.navigate', { url: '⟪ADAPT: stage-url⟫' });
```

## Грабли (полный каталог — в mobile-harness.md)

- Форвард умирает при рестарте приложения (сокет = PID) → пере-резолви `webview_devtools_remote_<pid>`.
- `connectOverCDP` не поддержан на новом WebView → только сырой websocket.
- `Fetch.fulfillRequest` (CDP-подмена 5xx) **не** триггерит нативный `onReceivedHttpError` → бесполезен
  для теста нативных экранов ошибок; нужен реальный сетевой прокси (а он — системный CA, см. harness).
- Старый WebView эмулятора не тянет SPA → CDP цепляется, но страница = net-error/сплэш; native-краши
  тестируй через `am start`.
