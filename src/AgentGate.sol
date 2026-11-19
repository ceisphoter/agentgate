// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Minimal view of the SPACE ID Agent ID contract (BNB Chain):
/// an ERC-721, non-transferable identity NFT ("name.ai").
/// Holding one (balanceOf > 0) is the gate used by this contract.
interface IAgentID {
    function balanceOf(address owner) external view returns (uint256);
}

/// @title AgentGate — Agent ID gated campaigns, claims and check-ins
/// @notice Anyone can open a campaign; only Agent ID holders can claim.
///         One claim per Agent ID address per campaign, recorded on-chain
///         forever as a public, sybil-resistant participation proof.
///         Agent ID holders can also check in once per UTC day.
///
/// @dev Safety by design (Binance Agent ID Hackathon red lines):
///      - This contract is NOT payable and never holds, moves or
///        approves user assets. No transfers, no allowances, no fees.
///      - There is no contract owner and no admin function. The only
///        privileged role is a campaign's own creator, who can close
///        their own campaign. Nothing else can be changed after
///        deployment; the Agent ID contract address is immutable.
///      - Claims are free and require no approval of any kind.
contract AgentGate {
    IAgentID public immutable agentId;

    struct Campaign {
        address creator;
        string name;
        string uri; // project link / details page
        uint64 startTime; // 0 at creation means "starts immediately"
        uint64 endTime; // 0 means "no end"
        uint32 maxClaims; // 0 means "unlimited"
        uint32 claimCount;
        bool closed;
    }

    Campaign[] public campaigns;

    /// campaignId => claimer => claimed
    mapping(uint256 => mapping(address => bool)) public hasClaimed;
    /// claimer => has claimed at least one campaign (unique claimers)
    mapping(address => bool) public claimedEver;
    /// claimer => total daily check-ins
    mapping(address => uint32) public checkInCount;
    /// claimer => last check-in day (block.timestamp / 1 days)
    mapping(address => uint256) public lastCheckInDay;

    uint256 public totalClaims;
    uint256 public uniqueClaimers;
    uint256 public totalCheckIns;

    event CampaignCreated(uint256 indexed id, address indexed creator, string name);
    event CampaignClosed(uint256 indexed id);
    event Claimed(uint256 indexed id, address indexed claimer);
    event CheckedIn(address indexed claimer, uint256 day, uint32 totalCheckIns);

    error InvalidCampaign();
    error NotAgentHolder();
    error AlreadyClaimed();
    error AlreadyCheckedIn();
    error CampaignIsClosed();
    error CampaignNotStarted();
    error CampaignEnded();
    error CampaignFull();
    error NotCreator();
    error EmptyName();
    error BadWindow();

    constructor(address agentIdContract) {
        agentId = IAgentID(agentIdContract);
    }

    /// @notice True when `account` currently holds an Agent ID.
    function isAgentHolder(address account) public view returns (bool) {
        return agentId.balanceOf(account) > 0;
    }

    function campaignCount() external view returns (uint256) {
        return campaigns.length;
    }

    function getCampaign(uint256 id) external view returns (Campaign memory) {
        if (id >= campaigns.length) revert InvalidCampaign();
        return campaigns[id];
    }

    /// @notice Open a new Agent ID gated campaign. Anyone may create one.
    /// @param name Campaign title (required).
    /// @param uri Link to the project / campaign details.
    /// @param startTime Unix start time; 0 = starts immediately.
    /// @param endTime Unix end time; 0 = no end.
    /// @param maxClaims Claim cap; 0 = unlimited.
    function createCampaign(
        string calldata name,
        string calldata uri,
        uint64 startTime,
        uint64 endTime,
        uint32 maxClaims
    ) external returns (uint256 id) {
        if (bytes(name).length == 0) revert EmptyName();
        if (endTime != 0 && endTime <= startTime) revert BadWindow();
        id = campaigns.length;
        campaigns.push(
            Campaign({
                creator: msg.sender,
                name: name,
                uri: uri,
                startTime: startTime == 0 ? uint64(block.timestamp) : startTime,
                endTime: endTime,
                maxClaims: maxClaims,
                claimCount: 0,
                closed: false
            })
        );
        emit CampaignCreated(id, msg.sender, name);
    }

    /// @notice The campaign's own creator can close it to new claims.
    function closeCampaign(uint256 id) external {
        if (id >= campaigns.length) revert InvalidCampaign();
        Campaign storage c = campaigns[id];
        if (msg.sender != c.creator) revert NotCreator();
        c.closed = true;
        emit CampaignClosed(id);
    }

    /// @notice Claim a spot in a campaign. Agent ID holders only,
    /// one claim per address per campaign. Free; moves no assets.
    function claim(uint256 id) external {
        if (id >= campaigns.length) revert InvalidCampaign();
        Campaign storage c = campaigns[id];
        if (c.closed) revert CampaignIsClosed();
        if (block.timestamp < c.startTime) revert CampaignNotStarted();
        if (c.endTime != 0 && block.timestamp > c.endTime) revert CampaignEnded();
        if (c.maxClaims != 0 && c.claimCount >= c.maxClaims) revert CampaignFull();
        if (hasClaimed[id][msg.sender]) revert AlreadyClaimed();
        if (!isAgentHolder(msg.sender)) revert NotAgentHolder();

        hasClaimed[id][msg.sender] = true;
        c.claimCount += 1;
        totalClaims += 1;
        if (!claimedEver[msg.sender]) {
            claimedEver[msg.sender] = true;
            uniqueClaimers += 1;
        }
        emit Claimed(id, msg.sender);
    }

    /// @notice Daily check-in for Agent ID holders (one per UTC day).
    /// A lightweight, recurring proof that a real Agent ID is active.
    function checkIn() external {
        if (!isAgentHolder(msg.sender)) revert NotAgentHolder();
        uint256 day = block.timestamp / 1 days;
        if (checkInCount[msg.sender] > 0 && lastCheckInDay[msg.sender] == day) {
            revert AlreadyCheckedIn();
        }
        lastCheckInDay[msg.sender] = day;
        checkInCount[msg.sender] += 1;
        totalCheckIns += 1;
        emit CheckedIn(msg.sender, day, checkInCount[msg.sender]);
    }
}
