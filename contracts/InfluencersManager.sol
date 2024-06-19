//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CampaignManager.sol";

enum InfluencersActions {
    Follow,
    Like,
    Recast,
    Cast_Mention,
    Cast_Contains_Text,
    Cast_Contains_Embed,
    Cast_Reply
}

contract InfluencersManager {
    CampaignManager public campaignManager;
    address public admin;

    struct Influencer {
        uint fid;
        address custodyAddress;
        address verifiedAddress;
        uint spammerFactor;
        uint posId;
    }

    uint[] public influencersUIDs;
    mapping(uint => address) public influencerAddress; // fid => address THIS NEEDS REVISITING
    mapping(address => uint) public influencerFids; // fid => address  THIS NEEDS REVISITING
    mapping(uint => Influencer) public influencers; // fid => Influencer

    mapping(uint => mapping(uint => bool)) public isCampaignInfuencer; // campaign_uuid => fid => bool

    // campaign_uuid => fid => uint[8] //[follow_points,like_points,recast_points,cast_mention_points,cast_contains_text_points,cast_contains_embed_points,cast_reply_points,total_points]
    mapping(uint => mapping(uint => uint[8])) public campaignScores;
    mapping(uint => uint) public total_campaign_score; //campaign_uuid => total points from all influencers

    constructor() {
        admin = msg.sender;
    }

    modifier OnlyAdmin() {
        require(msg.sender == admin, "You aren't the admin");
        _;
    }

    //TODO Needs Revisitng -- This Needs to call Farcaster with msg.sender and get Fid
    function registerInfluencer(uint influencer_fid) external {
        require(
            influencer_fid != 0 && influencerFids[msg.sender] != 0,
            "Influencer already exists or is invalid"
        );

        influencerAddress[influencer_fid] = msg.sender;
        influencerFids[msg.sender] = influencer_fid;

        influencers[influencer_fid] = Influencer({
            fid: influencer_fid,
            custodyAddress: address(0),
            verifiedAddress: msg.sender,
            spammerFactor: 1,
            posId: influencersUIDs.length
        });

        influencersUIDs.push(influencer_fid);

        //CHAINLINK FUNCTION CHECK TO GO HERE
    }

    function registerToCampaign(uint campaign_uuid) external {
        require(
            campaignManager.isCampaignActive(campaign_uuid),
            "Campaign is not active"
        );

        uint influencerFid = influencerFids[msg.sender];
        require(
            !isCampaignInfuencer[campaign_uuid][influencerFid],
            "Influencer not in campaign"
        );
        isCampaignInfuencer[campaign_uuid][influencerFid] = true;

        campaignManager.registerInfluencerForCampaign(
            campaign_uuid,
            influencerFid
        );
    }

    function awardPoints(
        uint campaign_uuid,
        uint influencer_fid,
        InfluencersActions actionType,
        uint numFollowers
    ) external OnlyAdmin {
        require(
            isCampaignInfuencer[campaign_uuid][influencer_fid] ||
                campaignManager.isCampaignActive(campaign_uuid),
            "Influencer not in campaign or campaign not active"
        );

        uint[7] memory marksArray = campaignManager.getCampaignPointMarking(
            campaign_uuid
        );

        uint action_type = uint(actionType);
        uint basePoints = marksArray[action_type];
        uint totalPoints = basePoints * numFollowers;

        uint[8] storage influencerPointsArray = campaignScores[campaign_uuid][
            influencer_fid
        ];
        influencerPointsArray[action_type] += totalPoints;
        influencerPointsArray[influencerPointsArray.length - 1] += totalPoints;

        total_campaign_score[campaign_uuid] += totalPoints;
    }

    function deductPoints(
        uint campaign_uuid,
        uint influencer_fid,
        InfluencersActions actionType,
        uint numFollowers
    ) external OnlyAdmin {
        require(
            isCampaignInfuencer[campaign_uuid][influencer_fid] ||
                campaignManager.isCampaignActive(campaign_uuid),
            "Influencer not in campaign or campaign not active"
        );

        uint[7] memory marksArray = campaignManager.getCampaignPointMarking(
            campaign_uuid
        );

        Influencer storage _influencer = influencers[influencer_fid];

        uint action_type = uint(actionType);
        uint basePoints = marksArray[action_type];
        uint totalPoints = basePoints *
            numFollowers *
            _influencer.spammerFactor;
        _influencer.spammerFactor *= 2;

        uint[8] storage influencerPointsArray = campaignScores[campaign_uuid][
            influencer_fid
        ];

        if (influencerPointsArray[action_type] < totalPoints) {
            influencerPointsArray[action_type] = 0;
        } else {
            influencerPointsArray[action_type] -= totalPoints;
        }

        uint influencer_total_score = influencerPointsArray[
            influencerPointsArray.length - 1
        ];

        if (influencer_total_score < totalPoints) {
            total_campaign_score[campaign_uuid] -= influencer_total_score;
            influencer_total_score = 0;
            _influencer.spammerFactor = 1;
        } else {
            total_campaign_score[campaign_uuid] -= totalPoints;
            influencer_total_score -= totalPoints;
        }
        influencerPointsArray[
            influencerPointsArray.length - 1
        ] = influencer_total_score;
    }

    function getCampaignScoresForInfluencer(
        uint campaign_uuid,
        uint fid
    ) external view returns (uint[8] memory) {
        return campaignScores[campaign_uuid][fid];
    }

    function getTotalCampaignScoresForInfluencer(
        uint campaign_uuid,
        uint fid
    ) external view returns (uint) {
        return campaignScores[campaign_uuid][fid][7];
    }

    function setCampaignManager(address _campaignManager) external OnlyAdmin {
        campaignManager = CampaignManager(_campaignManager);
    }

    function changeAdmin(address _newAdmin) external OnlyAdmin {
        admin = _newAdmin;
    }
}
