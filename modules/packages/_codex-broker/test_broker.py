import asyncio
import contextlib
import copy
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
from broker import Broker, Failure, connection, rpc
import runner


def payload(consumer='one', **kw):
    value = dict(consumer=consumer,label='Fixture job',prompt='Private prompt',context={'value':1},
                 input={'version':'1','schema':{'type':'object','required':['value']}},
                 output={'version':'1','schema':{'type':'integer'}})
    value.update(kw)
    return value


class Tests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.calls=[]
        self.gate=asyncio.Event()
        async def runner(value, model):
            self.calls.append(value['consumer'])
            await self.gate.wait()
            return 42, {'input':2,'output':1}
        self.b=Broker(runner,'fixture',concurrency=1,backoff=.001)
        self.b.start()

    async def asyncTearDown(self):
        await self.b.close()

    async def call(self, op, job):
        return await self.b.call({'op':op,'id':job.id,'epoch':self.b.epoch})

    async def test_priorities_fifo_promotion_and_nonpreemption(self):
        first=self.b.submit(payload('first'))
        await asyncio.sleep(.01)
        a=self.b.submit(payload('background'))
        b=self.b.submit(payload('interactive', **{'class':'interactive'}))
        c=self.b.submit(payload('second-interactive', **{'class':'interactive'}))
        self.assertEqual([j.id for j in self.b.queue()],[b.id,c.id,a.id])
        await self.call('next', a)
        self.assertEqual(self.calls,['first'])
        self.gate.set()
        await asyncio.wait_for(c.done.wait(),1)
        self.assertEqual(self.calls,['first','background','interactive','second-interactive'])

    async def test_superseded_inflight_result_never_delivered(self):
        old=self.b.submit(payload(item='item',revision=1))
        await asyncio.sleep(.01)
        new=self.b.submit(payload(item='item',revision=2))
        self.gate.set()
        await asyncio.wait_for(new.done.wait(),1)
        self.assertEqual(old.state,'superseded')
        self.assertNotIn('result',await self.call('status',old))
        with self.assertRaises(Failure): self.b.submit(payload(item='item',revision=1))

    async def test_invalid_requests_never_execute(self):
        for changes in ({'model':'other'}, {'context':None}, {'class':'urgent'}, {'revision':True,'item':'x'}, {'output':{'version':'1','schema':{'$ref':'file:///private'}}}):
            with self.assertRaises(Failure): self.b.submit(payload(**changes))
        self.assertEqual(self.calls,[])

    async def test_schema_retries_and_transient_limit(self):
        count=0
        async def runner(value,model):
            nonlocal count
            count+=1
            return ('invalid' if count < 4 else 7), {}
        self.b.runner=runner
        j=self.b.submit(payload())
        await asyncio.wait_for(j.done.wait(),1)
        self.assertEqual(j.result,7)
        self.assertEqual(j.attempts,4)
        async def fail(*args): raise RuntimeError('secret')
        self.b.runner=fail
        j=self.b.submit(payload('bad'))
        await asyncio.wait_for(j.done.wait(),1)
        self.assertEqual(j.state,'failed')
        self.assertEqual(j.attempts,3)
        self.assertNotIn('secret',json.dumps(j.metadata()))
        self.b.runner=runner
        await self.call('retry',j)
        await asyncio.wait_for(j.done.wait(),1)
        self.assertEqual(j.state,'succeeded')

    async def test_retry_cancellation_and_release(self):
        async def invalid(*args): return 'bad',{}
        self.b.runner=invalid
        self.b.backoff=1
        j=self.b.submit(payload())
        await asyncio.sleep(.01)
        self.assertEqual(j.state,'retrying')
        await self.call('cancel',j)
        await asyncio.sleep(.01)
        self.assertEqual(j.state,'cancelled')
        await self.call('release',j)
        self.assertEqual(j.payload,{})
        self.assertNotIn(j.id,self.b.jobs)

    async def test_released_completion_is_brief_metadata_only(self):
        self.gate.set()
        job = self.b.submit(payload())
        await asyncio.wait_for(job.done.wait(), 1)
        await self.call('release', job)
        listing = await self.b.call({'op':'list'})
        self.assertEqual(listing['jobs'][0]['state'], 'succeeded')
        self.assertNotIn('Private prompt', json.dumps(listing))
        self.assertNotIn('result', json.dumps(listing))
        self.assertEqual(job.payload, {})
        with patch('broker.time.time', return_value=job.updated + 6):
            self.assertEqual((await self.b.call({'op':'list'}))['jobs'], [])

    async def test_two_socket_clients_disconnect_and_restart(self):
        with tempfile.TemporaryDirectory() as temp:
            path=str(Path(temp)/'broker.sock')
            server=await asyncio.start_unix_server(lambda r,w:connection(self.b,r,w),path)
            async with server:
                a=await rpc(path,{'op':'submit','request':payload('client-a')})
                b=await rpc(path,{'op':'submit','request':payload('client-b')})
                # Both submitting connections have closed; jobs continue.
                self.gate.set()
                for reply in (a,b):
                    result=await rpc(path,{'op':'wait','id':reply['job']['id'],'epoch':reply['epoch']})
                    self.assertEqual(result['result'],42)
                listing=await rpc(path,{'op':'list'})
                self.assertNotIn('Private prompt',json.dumps(listing))
                self.assertNotIn('context',json.dumps(listing))
                result=await rpc(path,{'op':'status','id':a['job']['id'],'epoch':'old'})
                self.assertEqual(result['error'],'broker_restarted')


class FeatureFlagTests(unittest.TestCase):
    def setUp(self):
        runner.feature_flags.cache_clear()

    @patch('runner.subprocess.run')
    def test_accepts_namespaced_feature(self, run):
        run.return_value = subprocess.CompletedProcess(
            args=[],
            returncode=0,
            stdout=(
                'guardianv2.thread_context under development false\n'
                'skip_host_skill_discovery under development false\n'
            ),
        )
        self.assertEqual(
            runner.feature_flags('codex-fixture'),
            [
                '--disable',
                'guardianv2.thread_context',
                '--enable',
                'skip_host_skill_discovery',
            ],
        )


if __name__=='__main__': unittest.main()
