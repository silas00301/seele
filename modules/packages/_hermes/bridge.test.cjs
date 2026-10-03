// Exercise the actual compiled Electron bridge with framework/process doubles.
const assert = require('node:assert/strict');
const path = require('node:path');
const vm = require('node:vm');
const { EventEmitter } = require('node:events');
const root = path.resolve(process.argv[2]);
const esbuild = require(path.join(root, 'node_modules/esbuild'));
const output = esbuild.buildSync({ entryPoints:[path.join(root,'apps/desktop/electron/seele-lifecycle.ts')],bundle:true,platform:'node',format:'cjs',external:['electron'],write:false }).outputFiles[0].text;
let handler;
let time=1000;
const timers=[];
const children=[];
const reports=[];
const lifecycleModule = {exports:{}};
vm.runInNewContext(output, { exports:lifecycleModule.exports, module:lifecycleModule, URL, Date:{now:()=>time}, setTimeout:(fn,ms)=>{timers.push({fn,ms});return timers.length}, require:name=>{
  if(name==='electron')return {ipcMain:{on:(_,fn)=>{handler=fn}}};
  if(name==='node:child_process')return {spawn:()=>{const child=new EventEmitter();child.stdin=new EventEmitter();child.stdin.end=text=>reports.push(JSON.parse(text));children.push(child);return child}};
  return require(name);
}});
const frame={url:'file:///fixture/index.html'};
const event={senderFrame:frame,sender:{id:10,mainFrame:frame}};
const secondary={senderFrame:frame,sender:{id:20,mainFrame:frame}};
// No renderer may publish before the actual primary window is registered.
handler(event,{state:'thinking',session:'secret-session'});
assert.equal(children.length,0);
lifecycleModule.exports.setPrimaryWebContentsId(10);
handler(secondary,{state:'idle',session:'secondary-session'});
assert.equal(children.length,0);
handler({...event,senderFrame:{url:'file:///guest.html'}},{state:'thinking',session:'secret-session'});
handler(event,{state:'thinking',session:'secret-session',prompt:'content'});
assert.equal(children.length,0);
handler(event,{state:'thinking',session:'secret-session',gateway:'https://user:password@selected.example/hermes/?token=secret#private'});
assert.equal(children.length,1);
assert.equal(reports[0].gateway,'https://selected.example/hermes/');
assert(!JSON.stringify(reports[0]).includes('password'));
assert(!JSON.stringify(reports[0]).includes('token=secret'));
assert.equal(reports[0].session.length,64);
assert(!JSON.stringify(reports[0]).includes('secret-session'));
handler(event,{state:'idle',session:'secret-session',gateway:'https://other.example/'});
handler(event,{state:'speaking',session:'secret-session',gateway:'https://other.example/'});
handler(event,{state:'idle',session:'',gateway:'file:///private'});
handler(event,{state:'idle',session:'',gateway:42});
// A valid secondary top-level renderer cannot replace pending primary work.
handler(secondary,{state:'idle',session:'secondary-session'});
assert.equal(children.length,1);
children[0].emit('close');
assert.equal(timers.length,1);
time+=timers[0].ms;timers[0].fn();
assert.equal(children.length,2);
assert.equal(reports[1].state,'speaking');
assert.equal(reports[1].gateway,'https://other.example/');
assert.equal(reports[1].session,reports[0].session);
assert(!JSON.stringify(reports).includes('secondary-session'));
// Error and close both happen on a failed spawn; they must finish only once.
children[1].emit('error',new Error('fixture'));children[1].emit('close');
handler(event,{state:'idle',session:''});
assert.equal(timers.length,2);
time+=timers[1].ms;timers[1].fn();
assert.equal(reports[2].state,'idle');
const hardening=esbuild.buildSync({entryPoints:[path.join(root,'apps/desktop/electron/hardening.ts')],bundle:true,platform:'node',format:'cjs',write:false}).outputFiles[0].text;
const holder={exports:{}};vm.runInNewContext(hardening,{exports:holder.exports,module:holder,require,Buffer,__filename:path.join(root,'fixture.cjs')});
const exported=holder.exports;
assert.equal(typeof exported.encryptDesktopSecret,'function');
assert.throws(()=>exported.encryptDesktopSecret('fixture',{isEncryptionAvailable:()=>false},{allowPlainText:true}), /Secure token storage is unavailable/);
assert.throws(()=>exported.encryptDesktopSecret('fixture',{getSelectedStorageBackend:()=> 'basic_text',isEncryptionAvailable:()=>true}), /Unlock the system wallet/);
assert.equal(exported.encryptDesktopSecret('fixture',{getSelectedStorageBackend:()=> 'gnome_libsecret',isEncryptionAvailable:()=>true,encryptString:()=>Buffer.from('encrypted')}).encoding,'safeStorage');
// A legacy saved plaintext token is reencoded on save without retyping it.
// A locked wallet throws before persistence and never mutates the old record.
const legacy = {encoding:'plain',value:'fixture-legacy'};
assert.equal(exported.resolvePersistedRemoteToken({incomingToken:'',persistToken:true,existingToken:legacy,encryptSecret:()=>({encoding:'safeStorage',value:'encrypted'})}).encoding,'safeStorage');
assert.throws(()=>exported.resolvePersistedRemoteToken({incomingToken:'',persistToken:true,existingToken:legacy,encryptSecret:()=>{throw new Error('wallet locked')}}), /wallet locked/);
assert.equal(legacy.encoding,'plain');
assert.equal(legacy.value,'fixture-legacy');
assert.equal(exported.resolvePersistedRemoteToken({incomingToken:'',persistToken:false,existingToken:legacy,encryptSecret:()=>{throw new Error('unexpected encryption')}}),legacy);
// Exercise the real toggle body: rejecting its setter after reencoding would
// still leak every saved token to disk. OFF must fail before either operation.
const fs = require('node:fs');
const main = fs.readFileSync(path.join(root, 'apps/desktop/electron/main.ts'), 'utf8');
assert(main.includes("import { setPrimaryWebContentsId } from './seele-lifecycle'"));
assert(main.includes('const createdMainWindow = mainWindow\n  setPrimaryWebContentsId(createdMainWindow.webContents.id)'));
const begin = main.indexOf('function applySecretStorageEncryption(on: boolean) {');
const end = main.indexOf('\nfunction encryptDesktopSecret(', begin);
assert(begin >= 0 && end > begin);
const toggle = esbuild.transformSync(main.slice(begin, end), {loader:'ts',format:'cjs'}).code;
let rewrites = 0;
let transitions = 0;
const toggleContext = {
  secretStoragePolicy:()=>({on:true,migrated:true}),
  rewriteAllStoredSecrets:()=>{rewrites++},
  setSecretStoragePolicy:()=>{transitions++},
  safeStorage:{isEncryptionAvailable:()=>true},
};
vm.runInNewContext(toggle + '\nthis.toggle = applySecretStorageEncryption', toggleContext);
for (const value of [false, undefined, 0, 'true']) {
  assert.throws(()=>toggleContext.toggle(value), /Seele requires the system wallet/);
  assert.equal(rewrites, 0);
  assert.equal(transitions, 0);
}
assert.equal(toggleContext.toggle(true).on, true);
assert.equal(rewrites, 0);
assert.equal(transitions, 0);
console.log('Actual Electron bridge bounds bursts, authenticates frames, hashes identities and prevents wallet downgrade before persisted-store writes');

const renderer = esbuild.buildSync({entryPoints:[path.join(root,'apps/desktop/src/store/seele-lifecycle.ts')],bundle:false,platform:'node',format:'cjs',write:false}).outputFiles[0].text;
let connection = {mode:'remote',baseUrl:'https://selected.example/',token:'private-token',wsUrl:'wss://selected.example/?ticket=private-ticket'};
let gatewayState = 'open';
const store = get => ({get,listen:()=>{}});
const rendererReports=[];
let heartbeat;
vm.runInNewContext(renderer, {setInterval:fn=>{heartbeat=fn},window:{hermesDesktop:{seeleLifecycle:value=>rendererReports.push(value)}},require:name=>{
  if (name==='@/store/session') return {$activeSessionId:store(()=>''),$connection:store(()=>connection),$gatewayState:store(()=>gatewayState)};
  if (name==='@/store/session-states') return {$workingSessionIds:store(()=>[])};
  if (name==='@/store/voice-playback') return {$voicePlayback:store(()=>({status:'idle'}))};
  if (name==='@/store/wake-word') return {$wakeWord:store(()=>({listening:false}))};
  throw new Error(name);
}});
assert.equal(rendererReports[0].state,'idle');
assert.equal(rendererReports[0].gateway,'https://selected.example/');
assert(!JSON.stringify(rendererReports).includes('private-'));
connection = {...connection,baseUrl:'https://changed.example/'};
heartbeat();
assert.equal(rendererReports.at(-1).gateway,'https://changed.example/');
gatewayState = 'closed'; heartbeat();
assert.equal(rendererReports.at(-1).state,'disconnected');
connection = null; heartbeat();
assert.equal(rendererReports.at(-1).gateway,'');
console.log('Renderer follows the selected Desktop gateway without copying credentials');

// Run the actual login-window path with Electron and clocks replaced. Background
// retries must neither reveal windows nor create a window per concurrent request.
async function checkLoginWindows() {
  const start = main.indexOf('// Open a gateway login window in the OAuth session partition');
  const end = main.indexOf('// JSON request routed through the OAuth session partition', start);
  assert(start >= 0 && end > start);
  const code = esbuild.transformSync(main.slice(start, end), {loader:'ts',format:'cjs'}).code;
  const windows = [];
  const deadlines = [];
  class LoginWindow extends EventEmitter {
    constructor(options) { super(); this.visible=options.show; this.destroyed=false; this.webContents=new EventEmitter(); windows.push(this); }
    isVisible() { return this.visible; }
    isDestroyed() { return this.destroyed; }
    show() { this.visible=true; }
    destroy() { this.destroyed=true; this.visible=false; this.emit('closed'); }
    loadURL() { return Promise.resolve(); }
  }
  const context = {
    URL, BrowserWindow:LoginWindow, app:{isReady:()=>true},
    canShowInteractiveOauthLogin:()=>true,
    getOauthSessionForUrl:()=>({}),
    resolveOauthPartitionForUrl:(_,options)=>options.connectionId || 'default',
    normalizeRemoteBaseUrl:url=>url.replace(/\/$/,''),
    hasOauthSessionCookie:async()=>false,
    installWindowRendererLifecycle:()=>{}, rememberLog:()=>{},
    headersForRemoteRequest:()=>({}), oauthLoginLoadUrlOptions:()=>({}),
    setInterval:()=>1, clearInterval:()=>{}, clearTimeout:()=>{},
    setTimeout:(fn,ms)=>{deadlines.push({fn,ms});return deadlines.length},
  };
  vm.runInNewContext(code+'\nthis.openLogin = openOauthLoginWindow',context);
  const results=[];
  const open = options => { const p=context.openLogin('https://gateway.example',options); results.push(p.catch(()=>{})); return p; };
  open({silent:true}); open({silent:true});
  for (const timer of deadlines.filter(t=>t.ms===2500)) timer.fn();
  assert.equal(windows.filter(w=>w.visible).length,0,'automatic recovery revealed sign-in windows');
  assert.equal(windows.length,1,'concurrent retries created duplicate login windows');
  open({silent:true,connectionId:'other-account'});
  assert.equal(windows.length,2,'different session partitions must stay separate');
  open({}); open({});
  assert.equal(windows.filter(w=>w.visible).length,1,'explicit sign-in should show exactly one window');
  assert.equal(windows.length,3,'explicit login must not wait behind background recovery');
  const timeouts=deadlines.filter(t=>t.ms===12000);
  assert.equal(timeouts.length,2,'each hidden attempt must have a deadline');
  for (const timer of timeouts) timer.fn();
  await Promise.resolve();
  assert.equal(windows.filter(w=>!w.destroyed).length,1);
  windows.find(w=>w.visible).destroy();
  await Promise.all(results);
  open({});
  assert.equal(windows.filter(w=>w.visible).length,1,'closing a login must allow a later explicit attempt');
  windows.at(-1).destroy();
  await Promise.all(results);
  console.log('OAuth retries stay hidden, bounded and shared; explicit sign-in stays available');
}
checkLoginWindows().catch(error=>{console.error(error);process.exitCode=1});
