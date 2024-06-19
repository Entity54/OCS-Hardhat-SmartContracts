//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./InfluencersManager.sol";

// import {InfluencersActions} from "./InfluencersManager.sol";

contract CampaignManager {
    InfluencersManager public influencersManager;

    address public admin;
    uint public fees_percentage = 10;
    uint public campaign_nonce = 0;

    enum CampaignState {
        Pending,
        Active,
        Expired,
        ReadyForPayment,
        Void
    }

    struct InfluencerActionsPoints {
        uint follow_points;
        uint like_points;
        uint recast_points;
        uint cast_mention_points;
        uint cast_contains_text_points;
        uint cast_contains_embed_points;
        uint cast_reply_points;
    }

    struct Campaign {
        uint uuid;
        address owner;
        uint campaign_Fid;
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

    uint[] public activeCampaignUIDs;
    uint[] public pendingCampaignUIDs;
    uint[] public expiredCampaignUIDs;
    uint[] public readyFroPaymentCampaignUIDs;

    mapping(uint => Campaign) public campaigns; // uuid => Campaign
    mapping(uint => bool) public isCampaignActive; // uuid => bool
    mapping(address => uint) public campaignBalances;

    mapping(uint => bool) public isCampaignDistributionComplete; // uuid => bool
    mapping(uint => bool) public isCampaignPaymentsComplete; // uuid => bool

    mapping(uint => uint[]) public campaignInfluencers; // uuid => array of fids
    mapping(uint => uint[7]) public campaignPointMarking; // uuid => array of points per InfluencersActions

    mapping(uint => uint) public platform_campaign_fees; // campaign uuid => fees for Plarform
    mapping(address => uint) public platform_Balance; // platform income

    constructor() {
        admin = msg.sender;
    }

    modifier OnlyAdmin() {
        require(msg.sender == admin, "You aren't the admin");
        _;
    }

    // Register a new Campaigh  e.f. 1, "Description", 1, 1632960000, 1632960000, [1, 1, 3, 2, 3, 3, 2]
    function createCampaign(
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

        campaign_nonce++;

        campaignBalances[msg.sender] += msg.value;
    }

    // Activate a Campaign
    function checkPendingCampainStatus(uint _uuid) external {
        Campaign storage _campaign = campaigns[_uuid];

        require(
            _campaign.owner != address(0) &&
                _campaign.state == CampaignState.Pending,
            "Campaign either does not exist or is not pending"
        );

        if (_campaign.startTime >= block.timestamp) {
            deleteElementFromArray(pendingCampaignUIDs, _campaign.posId);
            // uint position = _campaign.posId;
            // uint lastPosition = pendingCampaignUIDs.length - 1;
            // if (position < lastPosition) {
            //     uint lastItemValue = pendingCampaignUIDs[lastPosition];
            //     pendingCampaignUIDs[position] = lastItemValue;
            //     campaigns[lastItemValue].posId = position;
            // }
            // pendingCampaignUIDs.pop();

            _campaign.posId = activeCampaignUIDs.length;
            _campaign.state = CampaignState.Active;
            activeCampaignUIDs.push(_uuid);

            isCampaignActive[_uuid] = true;
        }
    }

    // Expire a Campaign
    function checkActiveCampainStatus(uint _uuid) external {
        Campaign storage _campaign = campaigns[_uuid];

        require(
            _campaign.owner != address(0) &&
                _campaign.state == CampaignState.Active,
            "Campaign either does not exist or is not active"
        );

        if (_campaign.endTime >= block.timestamp) {
            deleteElementFromArray(activeCampaignUIDs, _campaign.posId);
            // uint position = _campaign.posId;
            // uint lastPosition = activeCampaignUIDs.length - 1;
            // if (position < lastPosition) {
            //     uint lastItemValue = activeCampaignUIDs[lastPosition];
            //     activeCampaignUIDs[position] = lastItemValue;
            //     campaigns[lastItemValue].posId = position;
            // }
            // activeCampaignUIDs.pop();

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

    function getCampaignPointMarking(
        uint _uuid
    ) external view returns (uint[7] memory) {
        return campaignPointMarking[_uuid];
    }

    function checkExpiredCampainStatus(uint _uuid) public {
        Campaign storage _campaign = campaigns[_uuid];

        require(
            _campaign.state == CampaignState.Expired &&
                isCampaignDistributionComplete[_uuid] == true,
            "Campaign is not expired or distributions are not complete"
        );

        //remove from Expired and move it to ReadyForPayment
        deleteElementFromArray(expiredCampaignUIDs, _campaign.posId);
        // uint position = _campaign.posId;
        // uint lastPosition = expiredCampaignUIDs.length - 1;
        // if (position < lastPosition) {
        //     uint lastItemValue = expiredCampaignUIDs[lastPosition];
        //     expiredCampaignUIDs[position] = lastItemValue;
        //     campaigns[lastItemValue].posId = position;
        // }
        // expiredCampaignUIDs.pop();

        _campaign.posId = readyFroPaymentCampaignUIDs.length;
        readyFroPaymentCampaignUIDs.push(_uuid);

        if (_campaign.influencersFids.length == 0)
            _campaign.state = CampaignState.Void; //campaign manaer can withdraw funds
        else _campaign.state = CampaignState.ReadyForPayment;
    }

    function calculateDistributions(uint _uuid) external {
        Campaign storage _campaign = campaigns[_uuid];

        require(
            _campaign.state == CampaignState.Expired &&
                isCampaignDistributionComplete[_uuid] == false,
            "Campaign is not expired or distributions are complete"
        );

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
            uint score = influencersManager.getTotalCampaignScoresForInfluencer(
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

    function withdrawPlatformFees() external OnlyAdmin {
        uint fees = platform_Balance[address(this)];
        platform_Balance[address(this)] = 0;
        payable(admin).transfer(fees);
    }

    function setInfluencersManagerr(
        address _influencersManager
    ) external OnlyAdmin {
        influencersManager = InfluencersManager(_influencersManager);
    }

    function changeAdmin(address _newAdmin) external OnlyAdmin {
        admin = _newAdmin;
    }
}
