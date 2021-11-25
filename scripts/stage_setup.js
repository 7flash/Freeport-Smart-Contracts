const Freeport = artifacts.require("Freeport");
const FiatGateway = artifacts.require("FiatGateway");
const log = console.log;

module.exports = async function (done) {

    // A fixed account for staging.
    // Mnemonic: "fatigue someone trip lottery grass special addict tiny erupt come spider duck"
    let serviceAccount = "0x50a2Cf81C5F8991780Ebc80222b835ecC4010956";

    let accounts = await web3.eth.getAccounts();
    let admin = accounts[0];
    let freeport = await Freeport.deployed();
    let gateway = await FiatGateway.deployed();
    log("Operating on Freeport contract", freeport.address);
    log("Operating on FiatGateway contract", gateway.address);
    log("From admin account", admin);

    const PAYMENT_SERVICE = await gateway.PAYMENT_SERVICE.call();

    log("Set an exchange rate of 0.1 token for $0.01");
    await gateway.setExchangeRate(0.1e10);

    log("Give the permission to execute payments to the service account", serviceAccount);
    await gateway.grantRole(PAYMENT_SERVICE, serviceAccount);

    let devAccounts = [
        gateway.address,
        serviceAccount,
    ];

    let amount = "10" + "000" + "000" + "0000000000"; // 10M with 10 decimals
    let encodedAmount = web3.eth.abi.encodeParameter('uint256', amount);

    for (let devAccount of devAccounts) {
        await freeport.deposit(devAccount, encodedAmount);
        log("Sent 10M of currency to", devAccount);
    }

    done();
};
