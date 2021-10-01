const SEOCoin = artifacts.require('./SEOCoin.sol');
const PreSale = artifacts.require('./PreSaleSEO.sol');

const rate = "100000";
const wallet = "0x5569BDF4e02cec3fE459796e3d0e741616029fA4";

const blackList = [
    "0xf3207c360a7cbeb6e359e79c3f690f1730897a19", 
    "0xAAE55e8342ecbBEcF836483aD54B90a32475065D",
    "0x8A8eFf48fBD6886FF67170BD893264f338c2c5DD",
    "0xC505F97fEA928d0820cee103EB4F9eD6e617f7a7"
];

module.exports = async (deployer) => {
    await deployer.deploy(SEOCoin, "SEO Coin", "SEO", 18, 1000000000, blackList);
    const SEOCoinInstance = await SEOCoin.deployed();
    console.log(
      `SEO coin contract deployed at ${SEOCoinInstance.address} in network: mainnet.`
    );

    await deployer.deploy(PreSale, SEOCoinInstance.address, rate, wallet);
    const preSaleInstance = await PreSale.deployed();
    console.log(
      `PreSale contract deployed at ${preSaleInstance.address} in network: mainnet.`
    );
  };
  