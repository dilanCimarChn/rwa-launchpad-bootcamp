import { test } from 'node:test';
import assert from 'node:assert/strict';
import { resolveConfig } from '../lib/config.ts';
test('default remains testnet', () => {
  assert.equal(resolveConfig({}).network, 'testnet');
  assert.equal(resolveConfig({}).sorobanRpcUrl, 'https://soroban-testnet.stellar.org');
});
test('non-test networks need explicit RPC and cannot reuse the known testnet endpoint', () => {
  for (const network of ['public', 'futurenet']) {
    assert.throws(() => resolveConfig({ NEXT_PUBLIC_NETWORK: network }), /explicit RPC/);
    assert.throws(() => resolveConfig({ NEXT_PUBLIC_NETWORK: network, NEXT_PUBLIC_SOROBAN_RPC_URL: 'https://soroban-testnet.stellar.org' }), /another network/);
    assert.equal(resolveConfig({ NEXT_PUBLIC_NETWORK: network, NEXT_PUBLIC_SOROBAN_RPC_URL: 'https://rpc.example.invalid' }).network, network);
  }
});
test('invalid networks and unsafe remote schemes fail closed', () => {
  assert.throws(() => resolveConfig({ NEXT_PUBLIC_NETWORK: 'typo' }), /Unsupported/);
  assert.throws(() => resolveConfig({ NEXT_PUBLIC_SOROBAN_RPC_URL: 'http://rpc.example.invalid' }), /HTTPS/);
  assert.equal(resolveConfig({ NEXT_PUBLIC_SOROBAN_RPC_URL: 'http://localhost:8000' }).sorobanRpcUrl, 'http://localhost:8000');
});
