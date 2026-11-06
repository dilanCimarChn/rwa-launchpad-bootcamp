export type AppNetwork = 'testnet' | 'public' | 'futurenet';

export function resolveConfig(env: Record<string, string | undefined>) {
  const network = (env.NEXT_PUBLIC_NETWORK ?? 'testnet').trim().toLowerCase();
  if (!['testnet', 'public', 'futurenet'].includes(network)) throw new Error('Unsupported Stellar network');
  const explicitRpc = env.NEXT_PUBLIC_SOROBAN_RPC_URL?.trim();
  if (network !== 'testnet' && !explicitRpc) throw new Error('An explicit RPC URL is required outside testnet');
  const rpc = new URL(explicitRpc || 'https://soroban-testnet.stellar.org');
  const local = ['localhost', '127.0.0.1', '[::1]'].includes(rpc.hostname);
  if (rpc.protocol !== 'https:' && !(rpc.protocol === 'http:' && local)) throw new Error('RPC requires HTTPS or local HTTP');
  if (network !== 'testnet' && rpc.hostname === 'soroban-testnet.stellar.org') throw new Error('Testnet RPC cannot serve another network');
  return {
    contractId: env.NEXT_PUBLIC_CONTRACT_ID?.trim() || undefined,
    paymentTokenId: env.NEXT_PUBLIC_PAYMENT_TOKEN_ID?.trim() || undefined,
    adminAddress: env.NEXT_PUBLIC_ADMIN_ADDRESS?.trim() || undefined,
    network: network as AppNetwork,
    sorobanRpcUrl: rpc.toString().replace(/\/$/, ''),
  };
}

export const config = resolveConfig(process.env);
export function isContractConfigured(): boolean { return Boolean(config.contractId); }
export function stellarExpertTxUrl(txHash: string): string {
  return `https://stellar.expert/explorer/${config.network}/tx/${encodeURIComponent(txHash)}`;
}
export const NOT_DEPLOYED_MESSAGE = 'Contract not deployed yet. Set NEXT_PUBLIC_CONTRACT_ID in your environment.';
