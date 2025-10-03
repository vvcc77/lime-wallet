import { readFileSync, mkdirSync, writeFileSync } from "fs";
import * as path from "path";

const artifacts = [
  "out/LimeVault.sol/LimeVault.json",
  "out/LimePaymaster.sol/LimePaymaster.json"
];

mkdirSync("abi", { recursive: true });

for (const p of artifacts) {
  const art = JSON.parse(readFileSync(path.resolve(p), "utf8"));
  const name = art.contractName || path.basename(p).split(".")[0];
  writeFileSync(`abi/${name}.json`, JSON.stringify(art.abi, null, 2));
  console.log(`ABI → abi/${name}.json`);
}
