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
vm.runInNewContext(output, { exports:lifecycleModule.exports, module:lifecycleModule, Date:{now:()=>time}, setTimeout:(fn,ms)=>{timers.push({fn,ms});return timers.length}, require:name=>{
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
handler(event,{state:'thinking',session:'secret-session'});
assert.equal(children.length,1);
assert.equal(reports[0].session.length,64);
assert(!JSON.stringify(reports[0]).includes('secret-session'));
handler(event,{state:'idle',session:'secret-session'});
handler(event,{state:'speaking',session:'secret-session'});
// A valid secondary top-level renderer cannot replace pending primary work.
handler(secondary,{state:'idle',session:'secondary-session'});
assert.equal(children.length,1);
children[0].emit('close');
assert.equal(timers.length,1);
time+=timers[0].ms;timers[0].fn();
assert.equal(children.length,2);
assert.equal(reports[1].state,'speaking');
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
