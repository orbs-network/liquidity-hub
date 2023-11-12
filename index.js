const { execSync } = require("child_process");

async function main() {
  const result = execSync("forge script CreateOrder").toString().trim();

  if (result != "0x0000000000000000000000000000000000000000")
    throw new Error("Wrong result!");
  return result;
}

main().then(console.log);
