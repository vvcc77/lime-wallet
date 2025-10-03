import "dotenv/config";
import { readFileSync } from "fs";
import { ethers } from "ethers";

const RPC = process.env.RPC_SEPOLIA!;
const PK  = process.env.PRIVATE_KEY!;

async function main() {
  const provider = new ethers.JsonRpcProvider(RPC);
  const wallet = new ethers.Wallet(PK, provider);

  // LimeVault
  {
    const art = JSON.parse(readFileSync("out/LimeVault.sol/LimeVault.json","utf8"));
    const factory = new ethers.ContractFactory(art.abi, art.bytecode.object, wallet);
    const token = process.env.TOKEN_ADDRESS!;
    const owner = process.env.OWNER_ADDRESS!;
    const treasury = process.env.TREASURY || ethers.ZeroAddress;
    const c = await factory.deploy(token, owner, treasury);
    const addr = await c.getAddress();
    console.log("LimeVault:", addr);
    await c.deploymentTransaction()?.wait();
  }

  // LimePaymaster
  {
    const art = JSON.parse(readFileSync("out/LimePaymaster.sol/LimePaymaster.json","utf8"));
    const factory = new ethers.ContractFactory(art.abi, art.bytecode.object, wallet);
    const entryPoint = process.env.ENTRYPOINT!;
    const token = process.env.TOKEN_ADDRESS!;
    const oracle = process.env.ORACLE_ADDRESS!;
    const c = await factory.deploy(entryPoint, token, oracle);
    const addr = await c.getAddress();
    console.log("LimePaymaster:", addr);
    await c.deploymentTransaction()?.wait();
  }
}

main().catch(e=>{ console.error(e); process.exit(1); });
