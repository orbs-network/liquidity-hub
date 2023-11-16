const { execSync } = require("child_process");
const path = require("path");

export async function createOrder(chainId, rfq) {
  const result = execSync(`cd ${path.dirname(__filename)} && \
  CHAIN=${chainId} \
  FOUNDRY_BLOCK_TIMESTAMP=${Math.round(Date.now() / 1000)} \
  LH_SWAPPER=${rfq.swapper} \
  LH_INTOKEN=${rfq.inToken} \
  LH_OUTTOKEN=${rfq.outToken} \
  LH_INAMOUNT=${rfq.inAmount} \
  LH_OUTAMOUNT=${rfq.outAmount} \
  forge script CreateOrder --silent --json`)
    .toString()
    .trim();
  const order = JSON.parse(result).returns;
  return {
    encoded: order?.encoded.value,
    hash: order?.hash.value,
    permitData: JSON.parse(order?.permitData.value),
  };
}
