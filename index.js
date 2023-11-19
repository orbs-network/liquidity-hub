const { exec } = require("child_process");
const promisify = require("util").promisify;
const execPromise = promisify(exec);
const path = require("path");

export async function createOrder(chainId, rfq) {
  const { stdout, stderr} = await execPromise(`cd ${path.dirname(__filename)} && \
  CHAIN=${chainId} \
  FOUNDRY_BLOCK_TIMESTAMP=${Math.round(Date.now() / 1000)} \
  LH_SWAPPER=${rfq.swapper} \
  LH_INTOKEN=${rfq.inToken} \
  LH_OUTTOKEN=${rfq.outToken} \
  LH_INAMOUNT=${rfq.inAmount} \
  LH_OUTAMOUNT=${rfq.outAmount} \
  forge script CreateOrder --silent --json --skip-simulation`);
  if (stderr) {
    throw new Error(stderr);
  }
  const order = JSON.parse(stdout.toString().trim()).returns;
  let permitData = JSON.parse(order?.permitData.value);
  if(typeof permitData == "string") {
      permitData = JSON.parse(permitData);
  }
  return {
    encoded: order?.encoded.value,
    hash: order?.hash.value,
    permitData: permitData,
  };
}
