//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./InfluencersManager.sol";

// import {InfluencersActions} from "./InfluencersManager.sol";

enum CampaignState {
    Pending,
    Active,
    Expired,
    ReadyForPayment,
    Void,
    Paid
}

struct Campaign {
    uint uuid;
    address owner;
    uint campaign_Fid;
    string title;
    string description;
    uint startTime;
    uint endTime;
    CampaignState state;
    uint budget;
    uint[] influencersFids;
    uint[] distributions;
    uint timestamp;
    uint posId;
}

contract CampaignManager {
    InfluencersManager public influencersManager;

    address public admin;
    uint public fees_percentage = 10;
    uint public campaign_nonce = 0;

    // enum CampaignState {
    //     Pending,
    //     Active,
    //     Expired,
    //     ReadyForPayment,
    //     Void,
    //     Paid
    // }

    struct InfluencerActionsPoints {
        uint follow_points;
        uint like_points;
        uint recast_points;
        uint cast_reply_points;
        uint cast_mention_points;
        uint cast_contains_text_points;
        uint cast_contains_embed_points;
    }

    // struct Campaign {
    //     uint uuid;
    //     address owner;
    //     uint campaign_Fid;
    //     string title;
    //     string description;
    //     uint startTime;
    //     uint endTime;
    //     CampaignState state;
    //     uint budget;
    //     uint[] influencersFids;
    //     uint[] distributions;
    //     uint timestamp;
    //     uint posId;
    // }

    uint[] public pendingCampaignUIDs;
    uint[] public activeCampaignUIDs;
    uint[] public expiredCampaignUIDs;
    uint[] public readyFroPaymentCampaignUIDs;
    uint[] public completedCampaignUIDs;

    mapping(uint => Campaign) public campaigns; // uuid => Campaign
    mapping(uint => bool) public isCampaignActive; // uuid => bool
    mapping(uint => uint) public campaignBalances; // uuid => uuid

    mapping(uint => bool) public isCampaignDistributionComplete; // uuid => bool
    mapping(uint => bool) public isCampaignPaymentsComplete; // uuid => bool

    // mapping(uint => uint[]) public campaignInfluencers; // uuid => array of fids
    mapping(uint => uint[7]) public campaignPointMarking; // uuid => array of points per InfluencersActions

    mapping(uint => uint) public platform_campaign_fees; // campaign uuid => fees for Platform
    mapping(address => uint) public platform_Balance; // platform income

    mapping(address => bool) public isAdministrator; //accounts with sub-administrator role

    constructor() {
        admin = msg.sender;
        isAdministrator[msg.sender] = true;
    }

    modifier OnlyAdmin() {
        require(msg.sender == admin, "You aren't the admin");
        _;
    }
    modifier OnlyAdmins() {
        require(isAdministrator[msg.sender], "You aren't an admin");
        _;
    }

    // Register a new Campaigh  e.f. 1, "Description", 1, 1632960000, 1632960000, [1, 1, 3, 2, 3, 3, 2]
    function createCampaign(
        string memory _title,
        string memory _description,
        uint _campaign_Fid,
        uint _startTime,
        uint _endTime,
        uint[7] calldata _influencerActionsPoints
    ) external payable {
        uint[] memory _influencersFids;
        uint[] memory _distributions;

        campaigns[campaign_nonce] = Campaign({
            uuid: campaign_nonce,
            owner: msg.sender,
            campaign_Fid: _campaign_Fid,
            title: _title,
            description: _description,
            startTime: _startTime,
            endTime: _endTime,
            state: CampaignState.Pending,
            budget: msg.value,
            influencersFids: _influencersFids,
            distributions: _distributions,
            timestamp: block.timestamp,
            posId: pendingCampaignUIDs.length
        });
        pendingCampaignUIDs.push(campaign_nonce);
        campaignPointMarking[campaign_nonce] = _influencerActionsPoints;

        campaignBalances[campaign_nonce] += msg.value;
        campaign_nonce++;
    }

    // Activate a Campaign
    function checkPendingCampainStatus(uint _uuid) external {
        Campaign storage _campaign = campaigns[_uuid];
        if (
            _campaign.owner != address(0) &&
            _campaign.state == CampaignState.Pending &&
            _campaign.startTime >= block.timestamp
        ) {
            deleteElementFromArray(pendingCampaignUIDs, _campaign.posId);

            _campaign.posId = activeCampaignUIDs.length;
            _campaign.state = CampaignState.Active;
            activeCampaignUIDs.push(_uuid);

            isCampaignActive[_uuid] = true;
        }
    }

    // Expire a Campaign
    function checkActiveCampainStatus(uint _uuid) external {
        Campaign storage _campaign = campaigns[_uuid];
        if (
            _campaign.owner != address(0) &&
            _campaign.state == CampaignState.Active
            // && _campaign.endTime >= block.timestamp
        ) {
            deleteElementFromArray(activeCampaignUIDs, _campaign.posId);

            _campaign.posId = expiredCampaignUIDs.length;
            _campaign.state = CampaignState.Expired;
            expiredCampaignUIDs.push(_uuid);

            isCampaignActive[_uuid] = false;
        }
    }

    // Register an Influencer for a Campaign
    function registerInfluencerForCampaign(uint _uuid, uint _fid) external {
        // require(
        //     msg.sender == address(influencersManager),
        //     "Only InfluencersManager contract can call this function"
        // );
        Campaign storage _campaign = campaigns[_uuid];

        require(
            _campaign.owner != address(0) &&
                (_campaign.state == CampaignState.Active ||
                    _campaign.state == CampaignState.Pending),
            "Campaign either does not exist or is not active or pending"
        );

        _campaign.influencersFids.push(_fid); //TODO checks if already infuencer in the InfluencerManager
    }

    function checkExpiredCampainStatus(uint _uuid) public {
        Campaign storage _campaign = campaigns[_uuid];
        if (
            _campaign.state == CampaignState.Expired &&
            isCampaignDistributionComplete[_uuid] == true
        ) {
            //remove from Expired and move it to ReadyForPayment
            deleteElementFromArray(expiredCampaignUIDs, _campaign.posId);

            _campaign.posId = readyFroPaymentCampaignUIDs.length;
            readyFroPaymentCampaignUIDs.push(_uuid);

            if (_campaign.influencersFids.length == 0)
                _campaign.state = CampaignState.Void; //campaign manaer can withdraw funds
            else _campaign.state = CampaignState.ReadyForPayment;
        }
    }

    function calculateDistributions(uint _uuid) external {
        Campaign storage _campaign = campaigns[_uuid];

        if (
            _campaign.state == CampaignState.Expired &&
            isCampaignDistributionComplete[_uuid] == false
        ) {
            uint[] memory influencersFids = _campaign.influencersFids;
            uint[] memory distributions = new uint[](influencersFids.length);

            uint fees = (fees_percentage * _campaign.budget) / 100;
            platform_campaign_fees[_uuid] = fees;

            uint budget = _campaign.budget - fees;
            uint total_campaign_score = influencersManager.total_campaign_score(
                _uuid
            );
            uint budgetleft = budget;

            for (uint i = 0; i < influencersFids.length - 1; i++) {
                uint score = influencersManager
                    .getTotalCampaignScoresForInfluencer(
                        _uuid,
                        influencersFids[i]
                    );

                uint allocation = (score * budget) / total_campaign_score;
                distributions[i] = allocation;
                budgetleft -= allocation;
            }
            distributions[influencersFids.length - 1] = budgetleft;

            _campaign.distributions = distributions;

            isCampaignDistributionComplete[_uuid] = true;
            checkExpiredCampainStatus(_uuid);
        }
    }

    function makePayments(uint _uuid) external {
        Campaign storage _campaign = campaigns[_uuid];

        require(
            _campaign.state == CampaignState.ReadyForPayment &&
                isCampaignPaymentsComplete[_uuid] == false,
            "Campaign is not ready for payment or already paid out"
        );

        uint[] memory influencersFids = _campaign.influencersFids;
        uint[] memory distributions = _campaign.distributions;

        for (uint i = 0; i < influencersFids.length; i++) {
            address influencerAddress = influencersManager.influencerAddress(
                influencersFids[i]
            );
            payable(influencerAddress).transfer(distributions[i]);
        }

        isCampaignPaymentsComplete[_uuid] = true;

        platform_Balance[address(this)] += platform_campaign_fees[_uuid];
        campaignBalances[_uuid] = 0;
    }

    function checkReadyForPaymentStatus(uint _uuid) public {
        Campaign storage _campaign = campaigns[_uuid];
        if (
            (_campaign.state == CampaignState.ReadyForPayment &&
                isCampaignPaymentsComplete[_uuid] == true) ||
            _campaign.state == CampaignState.Void
        ) {
            //remove from ReadyForPaymentStatus and move it to Completed
            deleteElementFromArray(
                readyFroPaymentCampaignUIDs,
                _campaign.posId
            );

            _campaign.posId = completedCampaignUIDs.length;
            completedCampaignUIDs.push(_uuid);

            if (_campaign.state == CampaignState.ReadyForPayment)
                _campaign.state = CampaignState.Paid;
        }
    }

    function deleteElementFromArray(uint[] storage arr, uint index) internal {
        uint lastPosition = arr.length - 1;
        if (index < lastPosition) {
            uint lastItemValue = arr[lastPosition];
            arr[index] = lastItemValue;
            campaigns[lastItemValue].posId = index;
        }
        arr.pop();
    }

    function withdrawVoidCampaignFunds(uint _uuid) external {
        Campaign storage _campaign = campaigns[_uuid];

        if (
            _campaign.state == CampaignState.Void &&
            _campaign.owner == msg.sender
        ) {
            uint campbalance = campaignBalances[_uuid];

            uint fees = (fees_percentage * campbalance) / 100;
            platform_campaign_fees[_uuid] = fees;
            platform_Balance[address(this)] += fees;
            campaignBalances[_uuid] = 0;
            payable(_campaign.owner).transfer(campbalance - fees);
        }
    }

    function withdrawPlatformFees() external OnlyAdmins {
        uint fees = platform_Balance[address(this)];
        platform_Balance[address(this)] = 0;
        payable(admin).transfer(fees);
    }

    function get_pendingCampaignUIDs() external view returns (uint[] memory) {
        return pendingCampaignUIDs;
    }

    function get_activeCampaignUIDs() external view returns (uint[] memory) {
        return activeCampaignUIDs;
    }

    function get_expiredCampaignUIDs() external view returns (uint[] memory) {
        return expiredCampaignUIDs;
    }

    function get_readyFroPaymentCampaignUIDs()
        external
        view
        returns (uint[] memory)
    {
        return readyFroPaymentCampaignUIDs;
    }

    function get_completedCampaignUIDss()
        external
        view
        returns (uint[] memory)
    {
        return completedCampaignUIDs;
    }

    function getCampaignPointMarking(
        uint _uuid
    ) external view returns (uint[7] memory) {
        return campaignPointMarking[_uuid];
    }

    function getCampaign(uint _uuid) external view returns (Campaign memory) {
        return campaigns[_uuid];
    }

    // influencersFids: _influencersFids,
    // distributions: _distributions,

    function getCampaign_influencersFids(
        uint _uuid
    ) external view returns (uint[] memory) {
        return campaigns[_uuid].influencersFids;
    }

    function getCampaign_distributions(
        uint _uuid
    ) external view returns (uint[] memory) {
        return campaigns[_uuid].distributions;
    }

    function getBlockTimestamp() external view returns (uint) {
        return block.timestamp;
    }

    function setInfluencersManager(
        address _influencersManager
    ) external OnlyAdmin {
        influencersManager = InfluencersManager(_influencersManager);
    }

    function changeAdmin(address _newAdmin) external OnlyAdmin {
        admin = _newAdmin;
    }

    function toggleAdministrator(address newAdministrator) external OnlyAdmin {
        require(
            admin != newAdministrator,
            "action only for toggling external administrators"
        );
        isAdministrator[newAdministrator] = !isAdministrator[newAdministrator];
    }
}
