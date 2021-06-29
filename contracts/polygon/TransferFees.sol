pragma solidity ^0.8.0;

import "./JointAccounts.sol";

/**
- Hold configuration of NFTs: services, royalties.
- Capture royalties on primary and secondary transfers.
- Report configured royalties to service providers (supports Joint Accounts).
 */
contract TransferFees is JointAccounts {

    // Royalties configurable per NFT by issuers.
    mapping(uint256 => address) public primaryRoyaltyAccounts;
    mapping(uint256 => uint256) public primaryRoyaltyCuts;
    mapping(uint256 => uint256) public primaryRoyaltyMinimums;
    mapping(uint256 => address) public secondaryRoyaltyAccounts;
    mapping(uint256 => uint256) public secondaryRoyaltyCuts;
    mapping(uint256 => uint256) public secondaryRoyaltyMinimums;

    /** Return the amount of royalties earned by an address on each primary and secondary transfer of an NFT.
     */
    function hasRoyalties(uint256 nftId, address beneficiary)
    public view returns (uint256 primaryCut, uint256 primaryMinimum, uint256 secondaryCut, uint256 secondaryMinimum) {

        // If the royalty account is the given beneficiary, return the configured fees.
        // Otherwise, the royalty account may be a Joint Account, and the beneficiary a share owner of it.
        // Otherwise, "fraction" will be 0, and 0 values will be returned.

        // Primary royalties.
        primaryCut = primaryRoyaltyCuts[nftId];
        primaryMinimum = primaryRoyaltyMinimums[nftId];
        address primaryAccount = primaryRoyaltyAccounts[nftId];
        if (primaryAccount != beneficiary) {
            uint256 fraction = fractionOfJAOwner(primaryAccount, beneficiary);
            primaryCut = primaryCut * fraction / BASIS_POINTS;
            primaryMinimum = primaryMinimum * fraction / BASIS_POINTS;
        }

        // Secondary royalties.
        secondaryCut = secondaryRoyaltyCuts[nftId];
        secondaryMinimum = secondaryRoyaltyMinimums[nftId];
        address secondaryAccount = secondaryRoyaltyAccounts[nftId];
        if (secondaryAccount != beneficiary) {
            uint256 fraction = fractionOfJAOwner(secondaryAccount, beneficiary);
            secondaryCut = secondaryCut * fraction / BASIS_POINTS;
            secondaryMinimum = secondaryMinimum * fraction / BASIS_POINTS;
        }

        return (primaryCut, primaryMinimum, secondaryCut, secondaryMinimum);
    }

    /** Configure the amounts and beneficiaries of royalties on primary and secondary transfers of this NFT.
     *
     * This setting is available to the issuer while he holds all NFTs of this type (normally right after issuance).
     *
     * A transfer is primary if it comes from the issuer of this NFT (normally the first sale after issuance).
     * Otherwise, it is a secondary transfer.
     *
     * A royalty is defined in two parts (both optional):
     * a cut of the sale price of an NFT, and a minimum royalty per transfer.
     * For simple transfers not attached to a price, or a too low price, the minimum royalty is charged.
     *
     * The cuts are given in basis points (1% of 1%). The minimums are given in currency amounts.
     *
     * There can be one beneficiary account for each primary and secondary royalties. To distribute revenues amongst
     * several parties, use a Joint Account (see function createDistributionAccount).
     */
    function setRoyalties(
        uint256 nftId,
        address primaryRoyaltyAccount,
        uint256 primaryRoyaltyCut,
        uint256 primaryRoyaltyMinimum,
        address secondaryRoyaltyAccount,
        uint256 secondaryRoyaltyCut,
        uint256 secondaryRoyaltyMinimum)
    public {
        address issuer = _msgSender();
        require(_isIssuerAndOnlyOwner(issuer, nftId));

        if (primaryRoyaltyCut != 0 || primaryRoyaltyMinimum != 0) {
            require(primaryRoyaltyAccount != address(0));
            primaryRoyaltyAccounts[nftId] = primaryRoyaltyAccount;
            primaryRoyaltyCuts[nftId] = primaryRoyaltyCut;
            primaryRoyaltyMinimums[nftId] = primaryRoyaltyMinimum;
        }

        if (secondaryRoyaltyCut != 0 || secondaryRoyaltyMinimum != 0) {
            require(secondaryRoyaltyAccount != address(0));
            secondaryRoyaltyAccounts[nftId] = secondaryRoyaltyAccount;
            secondaryRoyaltyCuts[nftId] = secondaryRoyaltyCut;
            secondaryRoyaltyMinimums[nftId] = secondaryRoyaltyMinimum;
        }
    }

    /** Internal hook to trigger the collection of royalties due on a batch of transfers.
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory tokenIds,
        uint256[] memory amounts,
        bytes memory data)
    internal override {
        // Pay a fee per transfer to a beneficiary, if any.
        for (uint256 i = 0; i < tokenIds.length; ++i) {
            _captureFee(from, tokenIds[i], /*price*/ 0, amounts[i]);
        }
    }

    /** Calculate the royalty due on a transfer.
     *
     * Collect the royalty using an internal transfer of currency.
     */
    function _captureFee(address from, uint256 nftId, uint256 price, uint256 amount)
    internal {
        if (nftId == CURRENCY) return;

        uint256 cut;
        uint256 minimum;
        address royaltyAccount;
        bool isPrimary = _isPrimaryTransfer(from, nftId);
        if (isPrimary) {
            cut = primaryRoyaltyCuts[nftId];
            minimum = primaryRoyaltyMinimums[nftId];
            royaltyAccount = primaryRoyaltyAccounts[nftId];
        } else {
            cut = secondaryRoyaltyCuts[nftId];
            minimum = secondaryRoyaltyMinimums[nftId];
            royaltyAccount = secondaryRoyaltyAccounts[nftId];
        }

        uint256 perTransferFee = price * cut / BASIS_POINTS;
        if (perTransferFee < minimum) perTransferFee = minimum;

        uint256 totalFee = perTransferFee * amount;
        if (totalFee != 0) {
            _forceTransfer(from, royaltyAccount, CURRENCY, totalFee);
        }
    }

    /** Determine whether a transfer is primary (true) or secondary (false).
     *
     * See the function setRoyalties.
     */
    function _isPrimaryTransfer(address from, uint256 nftId)
    internal pure returns (bool) {
        (address issuer, uint32 nonce, uint64 supply) = _parseNftId(nftId);
        return from == issuer;
    }

}