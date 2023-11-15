const { execSync } = require("child_process");

export async function createOrder(chainId, rfq) {
  const result = execSync(`CHAIN=${chainId} \
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
