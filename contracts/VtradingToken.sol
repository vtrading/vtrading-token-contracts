// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract VtradingToken is ERC20, ERC20Burnable, Ownable, ERC20Permit {
    // 1 billion tokens
    uint256 constant public totalTokens = 1000000000 * 10 ** 18;

    struct ReleaseInfo {
        uint256 releaseAmount;
        uint256 month;
        uint releaseTime;
        bool claimed;
        uint claimedTime;
    }

    struct VestingSchedule {
        address recipient;           // owner of the vesting schedule
        uint256 totalAllocated; // total tokens allocated
        uint256 released;        // total tokens released
        uint256 startRelease;
        bool startReleaseClaimed;
        ReleaseInfo[] releaseInfos;  // release information
        uint256 totalReleaseMonths;   // total release months
        uint256 lastClaimedMonth; // last claimed month
        uint lastClaimedTime; // last claimed time
    }


    mapping(string => VestingSchedule) private vestingSchedules;
    string[] public vestingNames;

    event UpdateVestingScheduleOwnerEvent(string indexed vestingName, address indexed oldOwner, address indexed newOwner);
    event SetVestingScheduleEvent(string indexed vestingName, VestingSchedule vestingSchedule);
    event ClaimVestedTokensEvent(string indexed vestingName, address indexed recipient, uint256 claimableAmount);

    constructor(address initialOwner)
    ERC20("VTrading Token", "VT")
    Ownable(initialOwner)
    ERC20Permit("VTrading Token")
    {}

    // claim the released tokens
    function claimVestedTokens(string memory vestingName) external {
        VestingSchedule storage vestingSchedule = vestingSchedules[vestingName];
        require(vestingSchedule.recipient != address(0), "Vesting schedule does not exist");
        require(vestingSchedule.recipient == msg.sender, "Only the recipient can claim the tokens");
        require(vestingSchedule.totalAllocated > 0, "Total allocated tokens must be greater than 0");
        require(vestingSchedule.released < vestingSchedule.totalAllocated, "All tokens have been released");
        require(vestingSchedule.lastClaimedMonth < vestingSchedule.totalReleaseMonths, "All tokens have been claimed");

        uint256 claimableAmount = 0;
        if (!vestingSchedule.startReleaseClaimed) {
            if (vestingSchedule.startRelease > 0) {
                claimableAmount += vestingSchedule.startRelease;
                vestingSchedule.startReleaseClaimed = true;
                vestingSchedule.released += vestingSchedule.startRelease;
            }
        }
        uint blockTimestamp = block.timestamp;

        uint256 totalMonths = vestingSchedule.totalReleaseMonths;
        uint256 totalAllocated = vestingSchedule.totalAllocated;
        uint256 totalReleased = vestingSchedule.released;
        uint256 lastClaimedMonth = vestingSchedule.lastClaimedMonth;

        for (uint256 i = lastClaimedMonth; i < totalMonths; i++) {
            ReleaseInfo memory releaseInfo = vestingSchedule.releaseInfos[i];
            // require(!releaseInfo.claimed, "Release info has already been claimed");
            if (!releaseInfo.claimed) {
                if (blockTimestamp >= releaseInfo.releaseTime) {
                    claimableAmount += releaseInfo.releaseAmount;

                    vestingSchedule.releaseInfos[i].claimed = true;
                    vestingSchedule.releaseInfos[i].claimedTime = blockTimestamp;

                    vestingSchedule.lastClaimedMonth = releaseInfo.month;
                    vestingSchedule.lastClaimedTime = blockTimestamp;
                    vestingSchedule.released += releaseInfo.releaseAmount;
                    totalReleased += releaseInfo.releaseAmount;
                    if (totalReleased >= totalAllocated) {
                        break;
                    }
                } else {
                    break;
                }
            }
        }
        if (claimableAmount > 0) {
            require(totalSupply() + claimableAmount <= totalTokens, "ERC20: mint amount exceeds total supply");
            _mint(vestingSchedule.recipient, claimableAmount);
        }
        emit ClaimVestedTokensEvent(vestingName, msg.sender, claimableAmount);
    }

    // set the vesting schedule,only once
    function setVestingSchedule(string memory vestingName, VestingSchedule memory vestingSchedule) external onlyOwner {
        require(vestingSchedule.recipient != address(0), "Recipient address cannot be 0");
        require(vestingSchedule.totalAllocated > 0, "Total allocated tokens must be greater than 0");
        require(vestingSchedule.releaseInfos.length == vestingSchedule.totalReleaseMonths, "Release info length must be equal to total release months");
        // Can't add something that already exists
        require(vestingSchedules[vestingName].recipient == address(0), "Vesting schedule already exists");

        uint256 totalReleaseAmount = vestingSchedule.startRelease;
        for (uint256 i = 0; i < vestingSchedule.releaseInfos.length; i++) {
            totalReleaseAmount += vestingSchedule.releaseInfos[i].releaseAmount;
        }

        require(totalReleaseAmount == vestingSchedule.totalAllocated, "Total release amount must match total allocated");

        // Check totalTokens is greater than totalAllocated
        uint256 vestingNameCount = vestingNames.length;
        uint256 allocatedTokens = vestingSchedule.totalAllocated;
        for (uint256 i = 0; i < vestingNameCount; i++) {
            allocatedTokens += vestingSchedules[vestingNames[i]].totalAllocated;
        }
        require(totalTokens >= allocatedTokens, "Total tokens must be greater than total allocated tokens");

        // Create a new VestingSchedule in storage
        VestingSchedule storage newSchedule = vestingSchedules[vestingName];
        newSchedule.recipient = vestingSchedule.recipient;
        newSchedule.totalAllocated = vestingSchedule.totalAllocated;
        newSchedule.startRelease = vestingSchedule.startRelease;
        newSchedule.totalReleaseMonths = vestingSchedule.totalReleaseMonths;

        newSchedule.released = 0; // Initially, nothing has been released
        newSchedule.lastClaimedMonth = 0;
        newSchedule.lastClaimedTime = 0;
        newSchedule.startReleaseClaimed = false;

        // Manually copy each ReleaseInfo
        for (uint256 i = 0; i < vestingSchedule.releaseInfos.length; i++) {
            newSchedule.releaseInfos.push(ReleaseInfo({
                releaseAmount: vestingSchedule.releaseInfos[i].releaseAmount,
                month: vestingSchedule.releaseInfos[i].month,
                releaseTime: vestingSchedule.releaseInfos[i].releaseTime,
                claimed: false, // Initially, nothing has been claimed
                claimedTime: 0
            }));
        }

        vestingNames.push(vestingName);
        emit SetVestingScheduleEvent(vestingName, newSchedule);
    }

    function queryVestingSchedule(string memory vestingName) external view returns (VestingSchedule memory) {
        return vestingSchedules[vestingName];
    }

    // update the vesting schedule owner
    function updateVestingScheduleOwner(string memory vestingName, address newOwner) external onlyOwner {
        VestingSchedule storage vestingSchedule = vestingSchedules[vestingName];
        require(vestingSchedule.recipient != address(0), "Vesting schedule does not exist");
        address oldOwner = vestingSchedule.recipient;
        vestingSchedule.recipient = newOwner;
        emit UpdateVestingScheduleOwnerEvent(vestingName, oldOwner, newOwner);
    }


}
