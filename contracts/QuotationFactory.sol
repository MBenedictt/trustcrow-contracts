// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Quotation.sol";

contract QuotationFactory is Ownable {
    mapping(address => address[]) public sellerQuotations;
    mapping(address => address[]) public buyerQuotations;

    event QuotationCreated(
        address indexed seller,
        address indexed quotationAddress,
        address indexed buyer,
        uint256 total,
        uint256 sellerStake
    );

    constructor() Ownable(msg.sender) {}

    function createQuotation(
        address buyer,
        uint256 totalAmount,
        uint256[] calldata milestonePercentsBP,
        uint256[] calldata milestoneDeadlines,
        uint256 clientWindowSeconds,
        uint8 maxRevisions
    ) external payable returns (address) {
        require(milestonePercentsBP.length == milestoneDeadlines.length, "length mismatch");

        uint256 sellerStakeAmount = msg.value; // REAL stake ETH

        // forward ETH stake to quotation contract
        Quotation q = new Quotation{value: msg.value}(
            msg.sender,
            buyer,
            totalAmount,
            milestonePercentsBP,
            milestoneDeadlines,
            clientWindowSeconds,
            maxRevisions,
            sellerStakeAmount
        );

        address qaddr = address(q);

        sellerQuotations[msg.sender].push(qaddr);
        if (buyer != address(0)) {
            buyerQuotations[buyer].push(qaddr);
        }

        emit QuotationCreated(msg.sender, qaddr, buyer, totalAmount, sellerStakeAmount);

        return qaddr;
    }

    function getUserQuotations(address user) external view returns (address[] memory) {
        return sellerQuotations[user];
    }

    function getBuyerQuotations(address user) external view returns (address[] memory) {
        return buyerQuotations[user];
    }
}
