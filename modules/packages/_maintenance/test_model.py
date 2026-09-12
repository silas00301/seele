import json
from pathlib import Path
import tempfile
import unittest
from model import Inbox, Invalid, WEEK

REG = {'disk':{'actions':{'recheck':{'label':'Recheck'}}}}

def report(**changes):
    return dict(key='root',title='Disk pressure',explanation='Space is low',urgency='soon',lifecycle='ongoing',actions=['recheck'],**changes)


class Tests(unittest.TestCase):
    def setUp(self):
        self.now = 1000000
        self.inbox = Inbox(REG,clock=lambda:self.now)

    def test_dedup_recurrence_and_order(self):
        a, notify = self.inbox.publish('disk', report())
        self.assertTrue(notify)
        self.now += 1
        b, notify = self.inbox.publish('disk', report())
        self.assertFalse(notify)
        self.assertEqual(a['updated'],b['updated'])
        self.assertEqual(a['revision'],b['revision'])
        self.inbox.resolve('disk','root')
        row, notify = self.inbox.publish('disk',report())
        self.assertTrue(notify)
        self.assertEqual(row['recurrence'],1)
        other=report();other.update(key='second',urgency='now')
        self.inbox.publish('disk',other)
        self.assertEqual(self.inbox.snapshot()['active'][0]['key'],'second')

    def test_lifecycle_and_snooze_escalation(self):
        row,_=self.inbox.publish('disk',report())
        with self.assertRaises(Invalid):self.inbox.operation(row['id'],row['revision'],'done')
        self.inbox.operation(row['id'],row['revision'],'snooze',3600)
        self.assertEqual(self.inbox.snapshot()['count'],0)
        self.assertEqual(len(self.inbox.snapshot()['snoozed']),1)
        escalated=report();escalated['urgency']='now'
        updated,notify=self.inbox.publish('disk',escalated)
        self.assertTrue(notify)
        self.assertEqual(self.inbox.snapshot()['count'],1)
        self.assertEqual(updated['snoozedUntil'],0)
        with self.assertRaises(Invalid):self.inbox.operation(row['id'],row['revision'],'snooze',60)

    def test_notice_expiry_and_history_retention(self):
        value=report();value.update(lifecycle='notice',urgency='informational')
        row,notify=self.inbox.publish('disk',value)
        self.assertFalse(notify)
        self.assertEqual(self.inbox.snapshot()['count'],0)
        self.inbox.operation(row['id'],row['revision'],'snooze',60)
        self.now+=61
        self.assertEqual(len(self.inbox.snapshot()['active']),1)
        self.inbox.operation(row['id'],row['revision'],'done')
        self.assertEqual(len(self.inbox.snapshot()['history']),1)
        self.now+=WEEK+1
        self.assertEqual(self.inbox.snapshot()['history'],[])

    def test_private_persistence_and_stale_analysis(self):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'state.json'
            inbox=Inbox(REG,path,clock=lambda:self.now)
            row,_=inbox.publish('disk',report(diagnostic='private diagnostic',details='token=secret'))
            inbox.analysis[row['id']]={'revision':row['revision'],'cause':'private output'}
            self.assertFalse(inbox.snapshot()['active'][0]['analysisStale'])
            value=report(diagnostic='changed');value['urgency']='now'
            inbox.publish('disk',value)
            self.assertTrue(inbox.snapshot()['active'][0]['analysisStale'])
            inbox.persist()
            saved=path.read_text()
            for private in ('private diagnostic','private output','token=secret'):
                self.assertNotIn(private,saved)
            self.assertEqual(path.stat().st_mode & 0o777,0o600)
            reloaded=Inbox(REG,path,clock=lambda:self.now)
            self.assertEqual(reloaded.diagnostics,{})
            self.assertFalse(reloaded.snapshot()['active'][0]['canAnalyze'])

    def test_contract_rejects_unregistered_commands(self):
        for source,value in [('unknown',report()),('disk',dict(report(),actions=['rm -rf /'])),('disk',dict(report(),command='x')),('disk',dict(report(),diagnostic='x'*16385))]:
            with self.assertRaises(Invalid):self.inbox.publish(source,value)

    def test_reload_rejects_corruption_and_discards_unrecognized_payloads(self):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'state.json'
            inbox=Inbox(REG,path,clock=lambda:self.now)
            inbox.publish('disk',report())
            rows=json.loads(path.read_text())
            rows[0].update(id='spoofed',diagnostic='private',analysis={'raw':'private'},unknown='private')
            rows += [dict(rows[0],key='broken',updated='invalid'),{'malformed':True}]
            path.write_text(json.dumps(rows))
            reloaded=Inbox(REG,path,clock=lambda:self.now)
            self.assertEqual(list(reloaded.items),['disk:root'])
            snapshot=json.dumps(reloaded.snapshot())
            self.assertNotIn('private',snapshot)
            reloaded.persist()
            self.assertNotIn('private',path.read_text())

    def test_types_are_rejected_without_mutation(self):
        for value in (dict(report(),key=2),dict(report(),actions=[{}]),dict(report(),urgency=[]),dict(report(),title={})):
            with self.assertRaises(Invalid):self.inbox.publish('disk',value)
        self.assertEqual(self.inbox.items,{})


if __name__=='__main__':unittest.main()
