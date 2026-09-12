#!/usr/bin/env python3
"""Private, memory-only inference jobs. The server never probes consumers."""
import argparse
import asyncio
import copy
import json
import os
import re
import signal
import socket
import struct
import sys
import time
import uuid
from dataclasses import dataclass, field

from jsonschema import Draft202012Validator, ValidationError, SchemaError

MAX_MESSAGE = 256 * 1024
TERMINAL = {'succeeded', 'failed', 'cancelled', 'superseded'}
CLASSES = {'interactive': 0, 'background': 10}
IDENTIFIER = re.compile(r'^[A-Za-z0-9_.:-]{1,100}$')


class Failure(Exception):
    def __init__(self, code):
        self.code = code
        super().__init__(code)


def schema(value):
    if not isinstance(value, dict) or not isinstance(value.get('version'), str):
        raise Failure('invalid_input')
    document = value.get('schema')
    # No reference resolution can fetch local files or remote schemas.
    def inspect(node, depth=0):
        if depth > 32:
            raise Failure('invalid_input')
        if isinstance(node, dict):
            if any(key in node for key in ('$ref', '$dynamicRef', '$recursiveRef')):
                raise Failure('invalid_input')
            for child in node.values():
                inspect(child, depth + 1)
        elif isinstance(node, list):
            for child in node:
                inspect(child, depth + 1)
    inspect(document)
    try:
        Draft202012Validator.check_schema(document)
    except (SchemaError, TypeError, RecursionError):
        raise Failure('invalid_input') from None
    return Draft202012Validator(document)


def request(value):
    allowed = {'consumer', 'label', 'prompt', 'context', 'input', 'output', 'class', 'item', 'revision'}
    if not isinstance(value, dict) or set(value) - allowed:
        raise Failure('invalid_input')
    if len(json.dumps(value).encode()) > MAX_MESSAGE:
        raise Failure('invalid_input')
    for key in ('consumer', 'label', 'prompt'):
        if not isinstance(value.get(key), str) or not value[key].strip():
            raise Failure('invalid_input')
    if not IDENTIFIER.fullmatch(value['consumer']) or len(value['label']) > 120:
        raise Failure('invalid_input')
    if any(ord(c) < 32 for c in value['label']):
        raise Failure('invalid_input')
    if value.get('class', 'background') not in CLASSES:
        raise Failure('invalid_input')
    if ('item' in value) != ('revision' in value):
        raise Failure('invalid_input')
    if 'item' in value and (not isinstance(value['item'], str) or len(value['item']) > 200
                            or type(value['revision']) is not int or not 0 <= value['revision'] < 2**63):
        raise Failure('invalid_input')
    validator = schema(value.get('input'))
    schema(value.get('output'))
    if not validator.is_valid(value.get('context')):
        raise Failure('invalid_input')
    return copy.deepcopy(value)


@dataclass
class Job:
    payload: dict
    sequence: int
    model: str
    id: str = field(default_factory=lambda: str(uuid.uuid4()))
    state: str = 'queued'
    created: float = field(default_factory=time.time)
    updated: float = field(default_factory=time.time)
    started: float = 0
    attempts: int = 0
    transient: int = 0
    tokens: dict = field(default_factory=lambda: {'input': 0, 'output': 0})
    error: str = ''
    result: object = None
    promoted: bool = False
    task: object = None
    done: asyncio.Event = field(default_factory=asyncio.Event)

    def metadata(self):
        return dict(id=self.id, consumer=self.payload['consumer'], label=self.payload['label'],
                    state=self.state, created=self.created, updated=self.updated,
                    started=self.started, model=self.model, attempts=self.attempts,
                    queueDuration=max(0, (self.started or time.time()) - self.created),
                    tokens=self.tokens.copy(), error=self.error)


class Broker:
    def __init__(self, runner, model, concurrency=2, capacity=128, retry_limit=2, backoff=1):
        self.runner, self.model = runner, model
        self.capacity, self.retry_limit, self.backoff = capacity, retry_limit, backoff
        self.jobs, self.workers = {}, []
        self.epoch = str(uuid.uuid4())
        self.sequence = 0
        self.changed = asyncio.Event()
        self.concurrency = concurrency
        self.activity = time.monotonic()

    def touch(self, job=None):
        self.activity = time.monotonic()
        if job:
            job.updated = time.time()
        self.changed.set()

    def start(self):
        self.workers = [asyncio.create_task(self.work()) for _ in range(self.concurrency)]

    def submit(self, value):
        value = request(value)
        if len(self.jobs) >= self.capacity:
            raise Failure('capacity')
        if 'item' in value:
            previous = [j for j in self.jobs.values() if j.payload['consumer'] == value['consumer']
                        and j.payload.get('item') == value['item']]
            if any(j.payload['revision'] >= value['revision'] for j in previous):
                raise Failure('superseded')
            for job in previous:
                self.finish(job, 'superseded')
                if job.task:
                    job.task.cancel()
        self.sequence += 1
        job = Job(value, self.sequence, self.model)
        self.jobs[job.id] = job
        self.touch(job)
        return job

    def queue(self):
        return sorted((j for j in self.jobs.values() if j.state == 'queued'),
                      key=lambda j: (not j.promoted, CLASSES[j.payload.get('class', 'background')], j.sequence))

    def finish(self, job, state, error=''):
        job.state, job.error = state, error
        if state != 'succeeded':
            job.result = None
        job.done.set()
        self.touch(job)

    async def attempt(self, job):
        job.attempts += 1
        result, usage = await self.runner(job.payload, job.model)
        for key in ('input', 'output'):
            amount = usage.get(key, 0)
            if type(amount) is int and amount >= 0:
                job.tokens[key] += amount
        try:
            schema(job.payload['output']).validate(result)
        except ValidationError:
            raise Failure('invalid_output') from None
        return result

    async def work(self):
        while True:
            queue = self.queue()
            if not queue:
                self.changed.clear()
                await self.changed.wait()
                continue
            job = queue[0]
            job.state = 'running'
            job.promoted = False
            job.started = job.started or time.time()
            self.touch(job)
            job.task = asyncio.create_task(self.attempt(job))
            try:
                result = await job.task
                if job.state not in TERMINAL:
                    job.result = result
                    self.finish(job, 'succeeded')
            except asyncio.CancelledError:
                if job.state not in TERMINAL:
                    raise
            except Exception as error:
                if job.state in TERMINAL:
                    continue
                code = error.code if isinstance(error, Failure) else 'runtime_failure'
                if code != 'invalid_output':
                    job.transient += 1
                if code != 'invalid_output' and job.transient > self.retry_limit:
                    self.finish(job, 'failed', code)
                else:
                    job.state = 'retrying'
                    self.touch(job)
                    # Backoff is its own task so this slot can serve newer work.
                    job.task = asyncio.create_task(self.requeue(job))
            finally:
                if job.state != 'retrying':
                    job.task = None

    async def requeue(self, job):
        await asyncio.sleep(min(30, self.backoff * 2 ** min(job.transient, 5)))
        if job.state == 'retrying':
            job.state = 'queued'
            self.sequence += 1
            job.sequence = self.sequence
            self.touch(job)

    async def call(self, message):
        self.touch()
        if not isinstance(message, dict):
            raise Failure('invalid_input')
        operation = message.get('op')
        if operation == 'submit':
            job = self.submit(message.get('request'))
            return {'job': job.metadata()}
        if operation == 'list':
            running = sorted((j for j in self.jobs.values() if j.state in ('running', 'retrying')), key=lambda j:j.sequence)
            terminal = sorted((j for j in self.jobs.values() if j.state in TERMINAL), key=lambda j:j.updated, reverse=True)
            return {'jobs': [j.metadata() for j in [*running, *self.queue(), *terminal]]}
        if message.get('epoch') != self.epoch:
            raise Failure('broker_restarted')
        job = self.jobs.get(message.get('id'))
        if not job:
            raise Failure('unknown_job')
        if operation == 'cancel':
            if job.state in TERMINAL:
                raise Failure('invalid_state')
            self.finish(job, 'cancelled')
            if job.task:
                job.task.cancel()
        elif operation == 'retry':
            if job.state != 'failed':
                raise Failure('invalid_state')
            job.done.clear()
            job.transient, job.error, job.state = 0, '', 'queued'
            self.touch(job)
        elif operation == 'next':
            if job.state != 'queued':
                raise Failure('invalid_state')
            for queued in self.queue():
                queued.promoted = False
            job.promoted = True
            self.touch(job)
        elif operation == 'release':
            if job.state not in TERMINAL:
                raise Failure('invalid_state')
            del self.jobs[job.id]
            job.payload.clear()
            job.result = None
            return {}
        elif operation == 'wait':
            await job.done.wait()
        elif operation != 'status':
            raise Failure('invalid_input')
        result = {'job': job.metadata()}
        if job.state == 'succeeded' and operation in ('status', 'wait'):
            result['result'] = job.result
        return result

    async def close(self):
        for job in self.jobs.values():
            if job.task:
                job.task.cancel()
        for worker in self.workers:
            worker.cancel()
        await asyncio.gather(*self.workers, *(j.task for j in self.jobs.values() if j.task), return_exceptions=True)
        self.jobs.clear()


async def connection(broker, reader, writer):
    try:
        peer = writer.get_extra_info('socket').getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, 12)
        if struct.unpack('3i', peer)[1] != os.getuid():
            writer.close()
            await writer.wait_closed()
            return
        raw = await asyncio.wait_for(reader.readline(), 10)
        message = json.loads(raw)
        reply = await broker.call(message)
        reply.update(ok=True, epoch=broker.epoch)
    except (Failure, ValueError, RecursionError, asyncio.TimeoutError) as error:
        reply = {'ok': False, 'error': error.code if isinstance(error, Failure) else 'invalid_input', 'epoch':broker.epoch}
    except (ConnectionError, BrokenPipeError):
        writer.close()
        return
    except Exception:
        reply = {'ok':False, 'error':'runtime_failure', 'epoch':broker.epoch}
    try:
        writer.write(json.dumps(reply, ensure_ascii=True).encode() + b'\n')
        await writer.drain()
    except (ConnectionError, BrokenPipeError):
        pass
    finally:
        writer.close()
        await writer.wait_closed()


async def rpc(path, message):
    try:
        reader, writer = await asyncio.open_unix_connection(path, limit=MAX_MESSAGE * 2)
        writer.write(json.dumps(message).encode() + b'\n')
        await writer.drain()
        result = json.loads(await reader.readline())
        writer.close()
        await writer.wait_closed()
        return result
    except (OSError, ValueError):
        return {'ok':False, 'error':'broker_unavailable'}


async def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('mode', choices=['serve', 'request', 'call'])
    parser.add_argument('--socket', default=os.path.join(os.environ.get('XDG_RUNTIME_DIR', '/nonexistent'), 'seele-codex.sock'))
    parser.add_argument('--model', default='gpt-5.6-luna')
    parser.add_argument('--concurrency', type=int, default=2)
    parser.add_argument('--idle', type=int, default=300)
    args = parser.parse_args()
    if args.mode != 'serve':
        raw = sys.stdin.buffer.read(MAX_MESSAGE + 1)
        try:
            if len(raw) > MAX_MESSAGE:
                raise ValueError()
            message = json.loads(raw)
        except ValueError:
            print(json.dumps({'ok':False, 'error':'invalid_input'}))
            return
        if args.mode == 'call':
            result = await rpc(args.socket, {'op':'submit', 'request':message})
            if result.get('ok'):
                identity = {'id':result['job']['id'], 'epoch':result['epoch']}
                result = await rpc(args.socket, {'op':'wait', **identity})
                await rpc(args.socket, {'op':'release', **identity})
        else:
            result = await rpc(args.socket, message)
        print(json.dumps(result))
        return
    from runner import infer
    broker = Broker(infer, args.model, concurrency=max(1, min(8, args.concurrency)))
    if os.environ.get('LISTEN_PID') != str(os.getpid()) or os.environ.get('LISTEN_FDS') != '1':
        raise SystemExit('broker requires its managed user socket')
    listener = socket.socket(fileno=3)
    server = await asyncio.start_unix_server(lambda r,w:connection(broker,r,w), sock=listener, limit=MAX_MESSAGE)
    broker.start()
    stop = asyncio.Event()
    for sig in (signal.SIGINT, signal.SIGTERM):
        asyncio.get_running_loop().add_signal_handler(sig, stop.set)
    try:
        while not stop.is_set():
            try:
                await asyncio.wait_for(stop.wait(), 1)
            except asyncio.TimeoutError:
                pass
            if all(j.state in TERMINAL for j in broker.jobs.values()) and time.monotonic() - broker.activity > args.idle:
                break
    finally:
        server.close()
        await server.wait_closed()
        await broker.close()


if __name__ == '__main__':
    asyncio.run(main())
