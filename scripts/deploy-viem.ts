import "dotenv/config";
import { createWalletClient, http, getAddress } from "viem";
import { sepolia } from "viem/chains";
import { privateKeyToAccount } from "viem/accounts";
import { readFileSync } from "fs";

const RPC = process.env.RPC_SEPOLIA!;
const PK  = process.env.PRIVATE_KEY as `0x${string}`;

async function deploy(artifactPath: string, args: any[]) {
  const account = privateKeyToAccount(PK);
  const client = createWalletClient({ account, chain: sepolia, transport: http(RPC) });

  const art = JSON.parse(readFileSync(artifactPath, "utf8"));
  const hash = await client.deployContract({
    abi: art.abi,
    bytecode: `0x${art.bytecode.object}`,
    args
  });
  console.log("tx:", hash);
}

async function main() {
  // Vault
  await deploy("out/LimeVault.sol/LimeVault.json", [
    getAddress(process.env.TOKEN_ADDRESS!),
    getAddress(process.env.OWNER_ADDRESS!),
    process.env.TREASURY ? getAddress(process.env.TREASURY!) : getAddress("0x0000000000000000000000000000000000000000")
  ]);

  // Paymaster
  await deploy("out/LimePaymaster.sol/LimePaymaster.json", [
    getAddress(process.env.ENTRYPOINT!),
    getAddress(process.env.TOKEN_ADDRESS!),
    getAddress(process.env.ORACLE_ADDRESS!)
  ]);
}

main().catch(e=>{ console.error(e); process.exit(1); });
