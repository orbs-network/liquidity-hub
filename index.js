const { execSync } = require("child_process");

async function main() {
  const CHAIN = process.env.CHAIN || 137;
  const rfq = {
    swapper: "0x0000000000000000000000000000000000000000",
    inToken: "0x0000000000000000000000000000000000000000",
    outToken: "0x0000000000000000000000000000000000000000",
    inAmount: 0,
    outAmount: 0,
  };
  const result = execSync(`CHAIN=${CHAIN} \
  LH_SWAPPER=${rfq.swapper} \
  LH_INTOKEN=${rfq.inToken} \
  LH_OUTTOKEN=${rfq.outToken} \
  LH_INAMOUNT=${rfq.inAmount} \
  LH_OUTAMOUNT=${rfq.outAmount} \
  forge script CreateOrder --silent --json`)
    .toString()
    .trim();
  const order = JSON.parse(result).returns;
  return order?.encoded.value;
}

main().then(console.log);
