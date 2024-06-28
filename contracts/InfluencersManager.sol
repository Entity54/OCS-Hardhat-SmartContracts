//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CampaignManager.sol";
import {CampaignState, Campaign} from "./CampaignManager.sol";

enum InfluencersActions {
    Follow,
    Like,
    Recast,
    Cast_Reply,
    Cast_Mention,
    Cast_Contains_Embed,
    Cast_Contains_Text
}

contract InfluencersManager {
    CampaignManager public campaignManager;
    address public admin;

    struct Influencer {
        uint fid;
        address custodyAddress; //farcaster custodyAddress
        address verifiedAddress; //address to get paid
        address ownerAddress; //address that registers influencer
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

    function registerInfluencer(
        uint influencer_fid,
        address _custodyAddress,
        address _verifiedAddress
    ) external {
        require(
            influencer_fid != 0 && influencerFids[msg.sender] == 0,
            "Influencer already exists or is invalid"
        );

        influencerAddress[influencer_fid] = _verifiedAddress;
        influencerFids[msg.sender] = influencer_fid;

        influencers[influencer_fid] = Influencer({
            fid: influencer_fid,
            custodyAddress: _custodyAddress,
            verifiedAddress: _verifiedAddress, //address to get paid
            ownerAddress: msg.sender,
            spammerFactor: 1,
            posId: influencersUIDs.length
        });

        influencersUIDs.push(influencer_fid);
    }

    function registerToCampaign(uint campaign_uuid) external {
        uint influencerFid = influencerFids[msg.sender];
        require(
            !isCampaignInfuencer[campaign_uuid][influencerFid],
            "Influencer already in campaign"
        );

        Campaign memory campaign = campaignManager.getCampaign(campaign_uuid);
        if (
            campaign.state == CampaignState.Pending ||
            campaign.state == CampaignState.Active
        ) {
            isCampaignInfuencer[campaign_uuid][influencerFid] = true;

            campaignManager.registerInfluencerForCampaign(
                campaign_uuid,
                influencerFid
            );
        }
    }

    function awardPoints(
        uint campaign_uuid,
        uint influencer_fid,
        InfluencersActions actionType,
        uint numFollowers
    ) external OnlyAdmins {
        if (
            isCampaignInfuencer[campaign_uuid][influencer_fid] &&
            campaignManager.isCampaignActive(campaign_uuid)
        ) {
            uint[7] memory marksArray = campaignManager.getCampaignPointMarking(
                campaign_uuid
            );

            uint action_type = uint(actionType);
            uint basePoints = marksArray[action_type];
            uint totalPoints = basePoints * numFollowers;

            uint[8] storage influencerPointsArray = campaignScores[
                campaign_uuid
            ][influencer_fid];
            influencerPointsArray[action_type] += totalPoints;
            influencerPointsArray[
                influencerPointsArray.length - 1
            ] += totalPoints; //Total points for influenecer fo this campaign

            total_campaign_score[campaign_uuid] += totalPoints; //Total points for campaign
        }
    }

    function deductPoints(
        uint campaign_uuid,
        uint influencer_fid,
        InfluencersActions actionType,
        uint numFollowers
    ) external OnlyAdmins {
        if (
            isCampaignInfuencer[campaign_uuid][influencer_fid] &&
            campaignManager.isCampaignActive(campaign_uuid)
        ) {
            uint[7] memory marksArray = campaignManager.getCampaignPointMarking(
                campaign_uuid
            );

            Influencer storage _influencer = influencers[influencer_fid];

            uint action_type = uint(actionType);
            uint basePoints = marksArray[action_type];
            uint totalPoints = basePoints * numFollowers;
            uint totalPointsWithSpammer = totalPoints *
                _influencer.spammerFactor;

            _influencer.spammerFactor *= 2;

            uint[8] storage influencerPointsArray = campaignScores[
                campaign_uuid
            ][influencer_fid];

            if (influencerPointsArray[action_type] < totalPointsWithSpammer) {
                influencerPointsArray[action_type] = 0;
            } else {
                influencerPointsArray[action_type] -= totalPointsWithSpammer;
            }

            uint influencer_total_score = influencerPointsArray[
                influencerPointsArray.length - 1
            ];

            if (influencer_total_score < totalPointsWithSpammer) {
                influencer_total_score = 0;
                _influencer.spammerFactor = 1;
            } else {
                influencer_total_score -= totalPointsWithSpammer;
            }

            influencerPointsArray[
                influencerPointsArray.length - 1
            ] = influencer_total_score;
        }
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

    function get_influencersUIDs() external view returns (uint[] memory) {
        return influencersUIDs;
    }

    function setCampaignManager(address _campaignManager) external OnlyAdmin {
        campaignManager = CampaignManager(_campaignManager);
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
