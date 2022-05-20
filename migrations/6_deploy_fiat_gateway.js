const Freeport = artifacts.require("Freeport");
const TestERC20 = artifacts.require("TestERC20");
const log = console.log;

module.exports = async function (deployer, network, accounts) {
    let isDev = (network === "development");
    if (isDev) {
        log("Deploying a test ERC20 on a development chain.");
        await deployer.deploy(TestERC20);
    }
    // Else, use the already deployed ERC20 for any new Freeport instance.

    let freeport = await Freeport.deployed();
    let erc20 = await TestERC20.deployed();
    log("Operating on Freeport contract", freeport.address);
    log("Operating on TestERC20 contract", erc20.address);

    log("Connect Freeport to TestERC20");
    await freeport.setERC20(erc20.address);
};