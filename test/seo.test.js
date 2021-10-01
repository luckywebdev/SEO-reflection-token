const { seoTokenTest } = require("./seotoken")
const { presaleTest } = require("./presale")

contract("SEO Coin and Presale", (accounts) => {
  describe("SEO Coin test", async () => seoTokenTest(accounts))
  describe("PreSale test", async () => presaleTest(accounts))
})
