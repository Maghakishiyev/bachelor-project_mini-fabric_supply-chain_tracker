import { connect, Gateway } from "@hyperledger/fabric-gateway";
import { randomUUID } from "crypto";

const RATE = Number(process.env.RATE || 20);      // tx/s
const DURATION = Number(process.env.SECONDS || 300);
const CC_NAME = "shipping";

// Simplified version of getGatewayFromEnv function from Part 3
// This should be replaced with your actual implementation from app/src/lib/fabric.ts
async function getGatewayFromEnv(): Promise<Gateway> {
  // Import your actual gateway connection code here
  // This is a placeholder - you need to adapt this from your existing app/src/lib/fabric.ts
  throw new Error("Please implement getGatewayFromEnv based on your fabric.ts implementation");
}

(async () => {
  // === gateway boiler-plate (reuse Next lib) ===
  const gw = await getGatewayFromEnv();           // helper from Part 3
  const net = gw.getNetwork("supplychain");
  const cc  = net.getContract(CC_NAME);

  const start = Date.now();
  let sent = 0;
  const timer = setInterval(async () => {
    if (Date.now() - start > DURATION * 1000) { clearInterval(timer); gw.close(); return; }
    const id = randomUUID().slice(0, 8);
    const t0 = Date.now();
    await cc.submitTransaction("CreateShipment", id, "Warsaw", "Berlin");
    const latency = Date.now() - t0;
    console.log(JSON.stringify({ id, latency, ts: t0 }));
    sent++;
  }, 1000 / RATE);
})();