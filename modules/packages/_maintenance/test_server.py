import asyncio
import json
from pathlib import Path
import tempfile
import unittest
from model import Inbox, Invalid
from server import Service, registrations, connection, rpc, run

CONFIG={'systemd':{'enabled':False},'backups':{'enabled':True,'items':[{'id':'daily','unit':'backup.service','scope':'user'}]},'disk':{'enabled':True},'flake':{'enabled':False},'certificates':{'enabled':False},'inputs':{'enabled':False}}

def finding(key='root', **kw):
    return dict(key=key,title='Disk pressure',explanation='Low space',urgency='soon',actions=['recheck'],diagnostic='Used blocks exceed threshold',**kw)


class Tests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.reports=[finding()]
        self.executed=[]
        async def collect(config,source):return self.reports
        async def execute(argv,**kw):self.executed.append(argv);return b''
        self.inbox=Inbox(registrations(CONFIG))
        self.service=Service(CONFIG,self.inbox,collect,execute)

    async def asyncTearDown(self):
        await self.service.close()

    async def settle(self):
        await asyncio.gather(*list(self.service.tasks.values()))

    async def test_publication_notifications_failure_and_recovery(self):
        await self.service.check('disk')
        await self.service.check('disk')
        self.assertEqual(len(self.executed),1)
        async def broken(*args):raise ValueError('secret error')
        self.service.collector=broken
        await self.service.check('disk')
        snapshot=await self.service.call({'op':'list'})
        self.assertEqual(snapshot['count'],1)
        self.assertNotIn('secret',json.dumps(snapshot))
        async def recovered(*args):return []
        self.service.collector=recovered
        await self.service.check('disk')
        self.assertEqual(self.inbox.snapshot()['count'],0)
        self.assertEqual(len(self.inbox.snapshot()['history']),1)

    async def test_typed_action_confirmation_and_no_commands(self):
        value=finding('daily');value['actions']=['retry','open-logs']
        row,_=self.inbox.publish('backups',value)
        request={'op':'action','id':row['id'],'revision':row['revision'],'action':'retry'}
        with self.assertRaises(Invalid):await self.service.call(request)
        await self.service.call(dict(request,confirmed=True))
        await self.settle()
        self.assertEqual(self.executed,[['systemctl','--user','restart','--','backup.service']])
        with self.assertRaises(Invalid):await self.service.call(dict(request,action='sh -c anything',confirmed=True))

    async def test_analysis_only_explicit_and_never_executes_proposals(self):
        row,_=self.inbox.publish('disk',finding())
        calls=[]
        gate=asyncio.Event()
        async def broker(message,timeout=10):
            calls.append(message)
            if message['op']=='submit':return {'ok':True,'epoch':'epoch','job':{'id':'job'}}
            if message['op']=='wait':
                await gate.wait()
                return {'ok':True,'result':{'cause':'Low capacity','evidence':['Threshold exceeded'],'nextSteps':['Review storage'],'actions':['recheck']}}
            return {'ok':True,'job':{'state':'succeeded'}}
        self.service.broker=broker
        await self.service.call({'op':'list'})
        self.assertEqual(calls,[])
        await self.service.call({'op':'analyze','id':row['id'],'revision':row['revision']})
        await asyncio.sleep(0)
        value=finding();value['urgency']='now'
        self.inbox.publish('disk',value)
        gate.set()
        await self.settle()
        row=self.inbox.snapshot()['active'][0]
        self.assertTrue(row['analysisStale'])
        self.assertEqual(row['analysis']['actions'],['recheck'])
        self.assertEqual(self.executed,[])
        context=calls[0]['request']['context']
        self.assertEqual(set(context),{'finding','diagnostic'})
        self.assertNotIn('outcomes',context['finding'])

    async def test_invalid_ai_repair_is_rejected(self):
        row,_=self.inbox.publish('disk',finding())
        async def broker(message,timeout=10):
            if message['op']=='submit':return {'ok':True,'epoch':'epoch','job':{'id':'job'}}
            if message['op']=='wait':return {'ok':True,'result':{'cause':'','evidence':[],'nextSteps':[],'actions':['arbitrary-command']}}
            return {'ok':True,'job':{'state':'succeeded'}}
        self.service.broker=broker
        await self.service.call({'op':'analyze','id':row['id'],'revision':row['revision']})
        await self.settle()
        self.assertEqual(self.inbox.analysis,{})
        self.assertEqual(self.executed,[])
        self.assertIn('unavailable',self.inbox.items[row['id']]['outcomes'][-1]['result'])

    async def test_socket_projection_and_stale_action(self):
        row,_=self.inbox.publish('disk',finding())
        with tempfile.TemporaryDirectory() as directory:
            path=str(Path(directory)/'test.sock')
            server=await asyncio.start_unix_server(lambda r,w:connection(self.service,r,w),path)
            async with server:
                reply=await rpc(path,{'op':'list'})
                self.assertTrue(reply['ok'])
                self.assertNotIn('Used blocks',json.dumps(reply))
                reply=await rpc(path,{'op':'snooze','id':row['id'],'revision':99,'seconds':60})
                self.assertFalse(reply['ok'])

    async def test_scheduled_action_revalidates_changed_and_resolved_findings(self):
        value=finding('daily');value['actions']=['retry']
        row,_=self.inbox.publish('backups',value)
        await self.service.call({'op':'action','id':row['id'],'revision':row['revision'],'action':'retry','confirmed':True})
        self.inbox.resolve('backups','daily')
        await asyncio.gather(*list(self.service.tasks.values()),return_exceptions=True)
        self.assertEqual(self.executed,[])
        self.assertEqual(self.inbox.items[row['id']]['busy'],'')

    async def test_invalid_later_report_keeps_entire_previous_snapshot(self):
        await self.service.check('disk')
        before=json.dumps(self.inbox.snapshot(),sort_keys=True)
        self.reports=[finding('new'),dict(finding('bad'),actions=['execute-command'])]
        await self.service.check('disk')
        self.assertEqual(before,json.dumps(self.inbox.snapshot(),sort_keys=True))
        self.assertEqual(len(self.executed),1)
        self.assertIn('disk',self.service.errors)

    async def test_recheck_waits_for_already_running_probe(self):
        gate=asyncio.Event()
        async def collect(*args):await gate.wait();return [finding()]
        self.service.collector=collect
        first=asyncio.create_task(self.service.check('disk'))
        await asyncio.sleep(0)
        second=asyncio.create_task(self.service.check('disk'))
        await asyncio.sleep(0)
        self.assertFalse(second.done())
        gate.set()
        await asyncio.gather(first,second)
        self.assertEqual(len(self.executed),1)

    async def test_close_during_broker_submit_cancels_accepted_job(self):
        row,_=self.inbox.publish('disk',finding())
        submitted=asyncio.Event();gate=asyncio.Event();calls=[]
        async def broker(message,timeout=10):
            calls.append(message['op'])
            if message['op']=='submit':
                submitted.set();await gate.wait()
                return {'ok':True,'epoch':'epoch','job':{'id':'job'}}
            if message['op']=='status':return {'ok':True,'job':{'state':'queued'}}
            return {'ok':True}
        self.service.broker=broker
        await self.service.call({'op':'analyze','id':row['id'],'revision':row['revision']})
        await submitted.wait()
        close=asyncio.create_task(self.service.close())
        await asyncio.sleep(0)
        gate.set()
        await close
        self.assertIn('cancel',calls)
        self.assertIn('release',calls)
        self.assertEqual(self.inbox.items[row['id']]['busy'],'')
        self.assertEqual(self.inbox.items[row['id']]['outcomes'][-1]['result'],'Cancelled')
        self.assertEqual(self.service.broker_jobs,{})

    async def test_logs_support_timer_unit_and_retry_uses_running_system(self):
        config={**CONFIG,'systemd':{'enabled':True}}
        inbox=Inbox(registrations(config))
        service=Service(config,inbox,executor=self.service.executor)
        value=finding('system/backup.timer');value['actions']=['open-logs']
        row,_=inbox.publish('systemd',value)
        await service.action(row,'open-logs',False)
        self.assertIn('--unit=backup.timer',self.executed[0])
        config['backups']={'enabled':True,'items':[dict(id='daily',unit='backup.service',scope='system')]}
        value=finding('daily');value['actions']=['retry']
        row,_=inbox.publish('backups',value)
        await service.action(row,'retry',True)
        self.assertEqual(self.executed[-1],['/run/current-system/sw/bin/run0','/run/current-system/sw/bin/systemctl','restart','--','backup.service'])
        await service.close()

    async def test_executor_limits_output_during_read(self):
        import sys
        with self.assertRaises(Invalid):
            await run([sys.executable,'-c','print("x"*300000)'])


if __name__=='__main__':unittest.main()
