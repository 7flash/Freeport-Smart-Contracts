pragma solidity ^0.8.0;

import "./access/AccessControl.sol";
import "./Davinci.sol";

/** The FiatGateway contract allows buying NFTs from an external fiat payment.
  *
  * This contract connects to the Davinci contract.
  * It must hold a balance of CERE recognized by Davinci.
  *
  * This contract uses the SimpleExchange API to buy NFTs.
 */
contract FiatGateway is AccessControl {

    bytes32 public constant EXCHANGE_RATE_ORACLE = keccak256("EXCHANGE_RATE_ORACLE");
    bytes32 public constant PAYMENT_SERVICE = keccak256("PAYMENT_SERVICE");

    /** The token ID that represents the CERE currency for all payments in this contract. */
    uint256 public constant CURRENCY = 0;

    Davinci public davinci;
    uint public cerePerPenny;

    /** How many USD cents were received so far, according to the payment service.
     */
    uint public totalPenniesReceived;

    /** How many CERE tokens were sold so far.
     */
    uint public totalCereSent;

    constructor(Davinci _davinci) {
        davinci = _davinci;

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    /** Set the exchange rate between fiat (USD) and Davinci currency (CERE).
      *
      * The rate is given as number of CERE (with 10 decimals) per USD cent (1 penny).
      *
      * Only the rate service with the EXCHANGE_RATE_ORACLE role can change the rate.
     */
    function setExchangeRate(uint _cerePerPenny)
    public onlyRole(EXCHANGE_RATE_ORACLE) {

        cerePerPenny = _cerePerPenny;
    }

    /** Withdraw all CERE from this contract.
      *
      * Only accounts with DEFAULT_ADMIN_ROLE can withdraw.
     */
    function withdraw()
    public onlyRole(DEFAULT_ADMIN_ROLE)
    returns (uint) {

        address admin = _msgSender();

        uint amount = davinci.balanceOf(address(this), CURRENCY);

        davinci.safeTransferFrom(
            address(this),
            admin,
            CURRENCY,
            amount,
            "");

        return amount;
    }

    /** Obtain CERE based on a fiat payment.
      *
      * The amount of fiat is recorded, and exchanged for an amount of CERE.
      *
      * Only the gateway with PAYMENT_SERVICE role can report successful payments.
     */
    function buyCereFromUsd(
        uint penniesReceived,
        address buyer,
        uint nonce)
    public onlyRole(PAYMENT_SERVICE)
    returns (uint) {
        require(cerePerPenny != 0, "Exchange rate must be configured");

        uint cereToSend = penniesReceived * cerePerPenny;

        davinci.safeTransferFrom(
            address(this),
            buyer,
            CURRENCY,
            cereToSend,
            "");

        totalPenniesReceived += penniesReceived;
        totalCereSent += cereToSend;

        return cereToSend;
    }

    /** Obtain CERE and buy an NFT based on a fiat payment.
      *
      * CERE tokens are obtained in the same way as buyCereFromUsd.
      *
      * Then, the tokens are used to buy an NFT in the same transaction. The NFT must be available for sale from the seller in SimpleExchange.
      *
      * Only the gateway with PAYMENT_SERVICE role can report successful payments.
     */
    function buyNftFromUsd(
        uint penniesReceived,
        address buyer,
        address seller,
        uint nftId,
        uint nftPrice,
        uint nonce)
    public onlyRole(PAYMENT_SERVICE) {

        uint boughtCere = buyCereFromUsd(penniesReceived, buyer, nonce);

        require(boughtCere >= nftPrice, "Not enough Cere to cover the NFT price");

        uint amount = 1;
        davinci.takeOffer(buyer, seller, nftId, nftPrice, amount);
    }

    /** Guarantee that a version of Solidity with safe math is used.
     */
    function _mathIsSafe() internal pure {
    unchecked {} // Use a keyword from Solidity 0.8.0.
    }
}