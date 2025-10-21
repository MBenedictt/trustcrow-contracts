import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import hre from "hardhat";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function main() {
    const Factory = await hre.ethers.getContractFactory("QuotationFactory");
    const factory = await Factory.deploy();
    await factory.waitForDeployment();

    const contractAddress = await factory.getAddress();
    console.log("QuotationFactory deployed at:", contractAddress);

    // Save address and ABI for frontend
    const contractsDir = path.join(__dirname, "..", "frontend-artifacts");
    if (!fs.existsSync(contractsDir)) {
        fs.mkdirSync(contractsDir);
    }

    fs.writeFileSync(
        path.join(contractsDir, "QuotationFactory-address.json"),
        JSON.stringify({ address: contractAddress }, null, 2)
    );

    const artifact = await hre.artifacts.readArtifact("QuotationFactory");
    fs.writeFileSync(
        path.join(contractsDir, "QuotationFactory.json"),
        JSON.stringify(artifact, null, 2)
    );
}

main().catch((err) => {
    console.error(err);
    process.exitCode = 1;
});