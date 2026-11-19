// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AgentGate, IAgentID} from "../src/AgentGate.sol";

contract MockAgentID is IAgentID {
    mapping(address => uint256) public bal;

    function set(address a, uint256 v) external {
        bal[a] = v;
    }

    function balanceOf(address a) external view returns (uint256) {
        return bal[a];
    }
}

contract AgentGateTest is Test {
    AgentGate gate;
    MockAgentID agentId;
    address holder = address(0xA11CE);
    address holder2 = address(0xB0B);
    address stranger = address(0xDEAD);
    address creator = address(0xC0FFEE);

    function setUp() public {
        agentId = new MockAgentID();
        gate = new AgentGate(address(agentId));
        agentId.set(holder, 1);
        agentId.set(holder2, 1);
    }

    function _campaign() internal returns (uint256 id) {
        vm.prank(creator);
        id = gate.createCampaign("Launch Drop", "https://example.org", 0, 0, 0);
    }

    function test_CreateCampaign() public {
        uint256 id = _campaign();
        assertEq(gate.campaignCount(), 1);
        AgentGate.Campaign memory c = gate.getCampaign(id);
        assertEq(c.creator, creator);
        assertEq(c.claimCount, 0);
    }

    function test_HolderCanClaim() public {
        uint256 id = _campaign();
        vm.prank(holder);
        gate.claim(id);
        assertTrue(gate.hasClaimed(id, holder));
        assertEq(gate.totalClaims(), 1);
        assertEq(gate.uniqueClaimers(), 1);
    }

    function test_NonHolderCannotClaim() public {
        uint256 id = _campaign();
        vm.prank(stranger);
        vm.expectRevert(AgentGate.NotAgentHolder.selector);
        gate.claim(id);
    }

    function test_DoubleClaimReverts() public {
        uint256 id = _campaign();
        vm.startPrank(holder);
        gate.claim(id);
        vm.expectRevert(AgentGate.AlreadyClaimed.selector);
        gate.claim(id);
        vm.stopPrank();
    }

    function test_UniqueClaimersCountsOnceAcrossCampaigns() public {
        uint256 a = _campaign();
        uint256 b = _campaign();
        vm.prank(holder);
        gate.claim(a);
        vm.prank(holder);
        gate.claim(b);
        assertEq(gate.totalClaims(), 2);
        assertEq(gate.uniqueClaimers(), 1);
        vm.prank(holder2);
        gate.claim(a);
        assertEq(gate.uniqueClaimers(), 2);
    }

    function test_MaxClaimsEnforced() public {
        vm.prank(creator);
        uint256 id = gate.createCampaign("Tiny", "", 0, 0, 1);
        vm.prank(holder);
        gate.claim(id);
        vm.prank(holder2);
        vm.expectRevert(AgentGate.CampaignFull.selector);
        gate.claim(id);
    }

    function test_WindowEnforced() public {
        uint64 start = uint64(block.timestamp + 1000);
        uint64 end = start + 1000;
        vm.prank(creator);
        uint256 id = gate.createCampaign("Window", "", start, end, 0);
        vm.prank(holder);
        vm.expectRevert(AgentGate.CampaignNotStarted.selector);
        gate.claim(id);
        vm.warp(end + 1);
        vm.prank(holder);
        vm.expectRevert(AgentGate.CampaignEnded.selector);
        gate.claim(id);
    }

    function test_OnlyCreatorCloses() public {
        uint256 id = _campaign();
        vm.prank(stranger);
        vm.expectRevert(AgentGate.NotCreator.selector);
        gate.closeCampaign(id);
        vm.prank(creator);
        gate.closeCampaign(id);
        vm.prank(holder);
        vm.expectRevert(AgentGate.CampaignIsClosed.selector);
        gate.claim(id);
    }

    function test_CheckInDaily() public {
        vm.prank(stranger);
        vm.expectRevert(AgentGate.NotAgentHolder.selector);
        gate.checkIn();

        vm.startPrank(holder);
        gate.checkIn();
        assertEq(gate.checkInCount(holder), 1);
        vm.expectRevert(AgentGate.AlreadyCheckedIn.selector);
        gate.checkIn();
        vm.warp(block.timestamp + 1 days);
        gate.checkIn();
        assertEq(gate.checkInCount(holder), 2);
        vm.stopPrank();
        assertEq(gate.totalCheckIns(), 2);
    }
}
