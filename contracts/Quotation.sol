// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Quotation is Ownable, ReentrancyGuard {
    enum OrderStatus { Created, Paid, InProgress, Completed, Refunded, Disputed, Cancelled }
    enum MilestoneStatus { Pending, Submitted, Approved, Released, Refunded }

    struct Milestone {
        uint256 percentBP;  
        uint256 amount;      
        MilestoneStatus status;
        uint256 submittedAt;
        uint8 revisions;
        uint256 deadlineAt;  
        string note;         
        bool buyerCancelConfirm;
        bool sellerCancelConfirm;
    }

    // order
    address public seller;
    address public buyer;
    uint256 public totalAmount;
    uint256 public paidAt;
    uint256 public createdAt;
    OrderStatus public status;
    uint256 public clientResponseWindow;
    uint256 public currentMilestone;
    Milestone[] private milestones;

    uint8 public maxRevisions;

    event QuotationCreated(address indexed seller, address indexed buyer, uint256 total);
    event Paid(address indexed payer, uint256 amount);
    event DeliverableSubmitted(uint256 indexed idx, string note);
    event MilestoneApproved(uint256 indexed idx, uint256 amount);
    event MilestoneReleased(uint256 indexed idx, uint256 amount);
    event MilestoneRefunded(uint256 indexed idx, uint256 amount);
    event OrderCompleted();
    event OrderCancelled();
    event DisputeRaised(address indexed by, string reason);
    event CancelProposed(address indexed by, uint256 indexed idx);
    event CancelConfirmed(uint256 indexed idx, uint256 refundAmount);
    event MaxRevisionsReached(uint256 indexed idx);

    constructor(
        address _seller,
        address _buyer,
        uint256 _totalAmount,
        uint256[] memory _milestonePercentsBP,
        uint256[] memory _milestoneDeadlines, 
        uint256 _clientWindowSeconds,
        uint8 _maxRevisions
    ) Ownable(_seller) {
        require(_seller != address(0), "seller zero");
        require(_totalAmount > 0, "total zero");
        require(_milestonePercentsBP.length == _milestoneDeadlines.length, "len mismatch");

        uint256 sum;
        for (uint i = 0; i < _milestonePercentsBP.length; i++) sum += _milestonePercentsBP[i];
        require(sum == 10000, "percents must sum 10000");

        seller = _seller;
        buyer = _buyer;
        totalAmount = _totalAmount;
        createdAt = block.timestamp;
        status = OrderStatus.Created;
        clientResponseWindow = _clientWindowSeconds == 0 ? 7 days : _clientWindowSeconds;
        currentMilestone = 0;
        maxRevisions = _maxRevisions;

        for (uint i = 0; i < _milestonePercentsBP.length; i++) {
            uint256 amt = (_totalAmount * _milestonePercentsBP[i]) / 10000;
            milestones.push(Milestone({
                percentBP: _milestonePercentsBP[i],
                amount: amt,
                status: MilestoneStatus.Pending,
                submittedAt: 0,
                revisions: 0,
                deadlineAt: _milestoneDeadlines[i], // offset for now
                note: "",
                buyerCancelConfirm: false,
                sellerCancelConfirm: false
            }));
        }

        emit QuotationCreated(seller, buyer, _totalAmount);
    }

    modifier onlySeller() {
        require(msg.sender == seller, "only seller");
        _;
    }
    modifier onlyBuyer() {
        require(buyer != address(0) && msg.sender == buyer, "only buyer");
        _;
    }
    modifier onlyParty() {
        require(msg.sender == seller || msg.sender == buyer, "not party");
        _;
    }

    function pay() external payable nonReentrant {
        require(status == OrderStatus.Created, "not payable");
        if (buyer != address(0)) require(msg.sender == buyer, "not buyer");
        require(msg.value == totalAmount, "wrong amount");
        paidAt = block.timestamp;
        status = OrderStatus.Paid;
        _setDeadlinesFromPaidAt();
        emit Paid(msg.sender, msg.value);
    }

    function _setDeadlinesFromPaidAt() internal {
        uint256 base = paidAt;
        for (uint i = 0; i < milestones.length; i++) {
            uint256 offset = milestones[i].deadlineAt;
            milestones[i].deadlineAt = base + offset;
        }
    }

    function submitDeliverable(uint256 idx, string calldata note) external onlySeller nonReentrant {
        require(status == OrderStatus.Paid || status == OrderStatus.InProgress, "not active");
        require(idx == currentMilestone, "not current milestone");
        Milestone storage m = milestones[idx];
        require(m.status == MilestoneStatus.Pending, "already submitted");
        require(block.timestamp <= m.deadlineAt, "deadline passed");

        m.status = MilestoneStatus.Submitted;
        m.submittedAt = block.timestamp;
        m.note = note;
        status = OrderStatus.InProgress;

        emit DeliverableSubmitted(idx, note);
    }

    function approveMilestone(uint256 idx) external onlyBuyer nonReentrant {
        Milestone storage m = milestones[idx];
        require(m.status == MilestoneStatus.Submitted, "not submitted");
        m.status = MilestoneStatus.Approved;
        _release(m, idx);

        m.buyerCancelConfirm = false;
        m.sellerCancelConfirm = false;

        currentMilestone++;
        if (currentMilestone >= milestones.length) {
            status = OrderStatus.Completed;
            emit OrderCompleted();
        }

        emit MilestoneApproved(idx, m.amount);
    }

    function _release(Milestone storage m, uint256 idx) internal {
        uint256 amt = m.amount;
        m.status = MilestoneStatus.Released;
        (bool ok, ) = payable(seller).call{value: amt}("");
        require(ok, "transfer failed");
        emit MilestoneReleased(idx, amt);
    }

    function requestRevision(uint256 idx, string calldata reason) external onlyBuyer {
        Milestone storage m = milestones[idx];
        require(m.status == MilestoneStatus.Submitted, "no submission");
        require(m.revisions < maxRevisions, "max revisions reached");
        m.revisions += 1;
        emit DisputeRaised(msg.sender, reason);

        if (m.revisions >= maxRevisions) {
            emit MaxRevisionsReached(idx);
        }
    }

    function autoReleaseIfClientSilent() external nonReentrant {
        require(status == OrderStatus.InProgress, "not in progress");
        Milestone storage m = milestones[currentMilestone];
        require(m.status == MilestoneStatus.Submitted, "not submitted");
        require(block.timestamp >= m.submittedAt + clientResponseWindow, "client window active");
        _release(m, currentMilestone);
        currentMilestone++;
        if (currentMilestone >= milestones.length) {
            status = OrderStatus.Completed;
            emit OrderCompleted();
        }
    }

    function claimRefundIfSellerNoSubmit() external nonReentrant {
        require(status == OrderStatus.Paid || status == OrderStatus.InProgress, "wrong status");
        Milestone storage m = milestones[currentMilestone];
        require(block.timestamp >= m.deadlineAt, "deadline not passed");
        uint256 refundAmount = _remainingAmount();
        status = OrderStatus.Refunded;
        _payout(buyer, refundAmount);
        emit MilestoneRefunded(currentMilestone, refundAmount);
    }

    function proposeCancel(uint256 idx) external onlyParty {
        Milestone storage m = milestones[idx];
        require(m.revisions >= maxRevisions, "not at max revisions");
        require(status == OrderStatus.Paid || status == OrderStatus.InProgress, "wrong status");

        if (msg.sender == buyer) {
            m.buyerCancelConfirm = true;
        } else {
            m.sellerCancelConfirm = true;
        }

        emit CancelProposed(msg.sender, idx);

        if (m.buyerCancelConfirm && m.sellerCancelConfirm) {
            uint256 refundAmount = _remainingAmount();
            status = OrderStatus.Refunded;
            _payout(buyer, refundAmount);
            emit CancelConfirmed(idx, refundAmount);
            emit OrderCancelled();
        }
    }

    function _remainingAmount() internal view returns (uint256 rem) {
        for (uint i = 0; i < milestones.length; i++) {
            if (milestones[i].status == MilestoneStatus.Pending || milestones[i].status == MilestoneStatus.Submitted) {
                rem += milestones[i].amount;
            }
        }
    }

    function _payout(address to, uint256 amt) internal {
        if (amt == 0) return;
        (bool s, ) = payable(to).call{value: amt}("");
        require(s, "payout failed");
    }

    function cancelBySeller() external onlySeller nonReentrant {
        require(status == OrderStatus.Created || status == OrderStatus.Paid, "cannot cancel");
        if (status == OrderStatus.Paid) {
            uint256 refund = _remainingAmount();
            status = OrderStatus.Refunded;
            _payout(buyer, refund);
        } else {
            status = OrderStatus.Cancelled;
        }
        emit OrderCancelled();
    }

    function milestoneCount() external view returns (uint256) {
        return milestones.length;
    }

    function getMilestone(uint256 idx) external view returns (
        uint256 percentBP,
        uint256 amount,
        MilestoneStatus ms,
        uint256 submittedAt,
        uint8 revisions,
        uint256 deadlineAt,
        string memory note,
        bool buyerCancelConfirm,
        bool sellerCancelConfirm
    ) {
        Milestone storage m = milestones[idx];
        return (m.percentBP, m.amount, m.status, m.submittedAt, m.revisions, m.deadlineAt, m.note, m.buyerCancelConfirm, m.sellerCancelConfirm);
    }

    function getOrder() external view returns (
        address _seller,
        address _buyer,
        uint256 _totalAmount,
        uint256 _paidAt,
        uint256 _createdAt,
        OrderStatus _status,
        uint256 _clientWindow,
        uint256 _currentMilestone,
        uint8 _maxRevisions
    ) {
        return (seller, buyer, totalAmount, paidAt, createdAt, status, clientResponseWindow, currentMilestone, maxRevisions);
    }

    function getRevisionLeft(uint256 idx) external view returns (uint8) {
        require(idx < milestones.length, "invalid idx");
        Milestone storage m = milestones[idx];
        if (m.revisions >= maxRevisions) return 0;
        return maxRevisions - m.revisions;
    }

    receive() external payable {}
}
