//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CampaignManager.sol";
import {CampaignState, Campaign} from "./CampaignManager.sol";
import "./InfluencersManager.sol";
import {InfluencersActions} from "./InfluencersManager.sol";
import "./CampaignAssets.sol";

contract SquawkProcessor {
CampaignManager public campaignManager;
InfluencersManager public influencersManager;
CampaignAssets public campaignAssets;

    address public admin;
    uint public nonce;
    uint public lastProcessedIndex;

    struct Squawk {
        uint[] data;
        uint created_at;
        uint code;
        uint user_fid;
        uint user_followers;
        address cast_hash;
        address replyTo_cast_hash;
        string embeded_string;
        uint nonce;
        uint processed; // 0 for not processed, 1 for processed
    }

    Squawk[] public squawkBox;

    constructor() {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "You aren't the admin");
        _;
    }

    function addSquawkData(Squawk[] memory newSquawks) external onlyAdmin {
        for (uint i = 0; i < newSquawks.length; i++) {
            newSquawks[i].nonce = nonce;
            newSquawks[i].processed = 0; // Ensure processed is set to 0
            squawkBox.push(newSquawks[i]);
            nonce += 1;
        }
    }

    // Pass _range = 0 to process all the squawk data
    function processSquawkData(uint _range) external onlyAdmin returns (bool) {
        if (squawkBox.length > 0 && lastProcessedIndex < nonce) {
            uint range = _range;

            if (range == 0) range = nonce - lastProcessedIndex;

            if (range > (nonce - lastProcessedIndex))
                range = nonce - lastProcessedIndex;

            uint startRange = lastProcessedIndex != 0
                ? lastProcessedIndex + 1
                : 0;
            uint endRange = lastProcessedIndex + range;

            for (uint i = startRange; i < endRange; i++) {
                squawkBox[i].processed = 1; // Mark as processed 1: processed, 0: not processed

                Squawk memory squawkmsg = squawkBox[i];

                uint campaign_fid = 0;

                // Do the points awarding here start
                if (squawkBox[i].code == 14) {
                    // FOLLOW
                    campaign_fid = squawkmsg.data[0];
                    uint campaign_uuid = campaignManager.campaignFidToUid(
                        campaign_fid
                    );

                    influencersManager.awardPoints(
                        campaign_uuid,
                        squawkmsg.user_fid,
                        InfluencersActions.Follow,
                        squawkmsg.user_followers
                    );
                } else if (squawkBox[i].code == 15) {
                    // UNFOLLOW
                    campaign_fid = squawkmsg.data[0];
                    uint campaign_uuid = campaignManager.campaignFidToUid(
                        campaign_fid
                    );

                    influencersManager.awardPoints(
                        campaign_uuid,
                        squawkmsg.user_fid,
                        InfluencersActions.UnFollow,
                        squawkmsg.user_followers
                    );
                } else if (squawkBox[i].code == 16 || squawkBox[i].code == 17) {
                    // REACTION
                    campaign_fid = squawkmsg.data[0];
                    uint campaign_uuid = campaignManager.campaignFidToUid(
                        campaign_fid
                    );

                    InfluencersActions actionType = squawkmsg.code == 16
                        ? InfluencersActions.Like
                        : InfluencersActions.Recast;

                    influencersManager.awardPoints(
                        campaign_uuid,
                        squawkmsg.user_fid,
                        actionType,
                        squawkmsg.user_followers
                    );
                } else if (squawkBox[i].code == 18 || squawkBox[i].code == 19) {
                    // REACTION DELETED
                    campaign_fid = squawkmsg.data[0];
                    uint campaign_uuid = campaignManager.campaignFidToUid(
                        campaign_fid
                    );

                    InfluencersActions actionType = squawkmsg.code == 18
                        ? InfluencersActions.Unlike
                        : InfluencersActions.UnRecact;

                    influencersManager.awardPoints(
                        campaign_uuid,
                        squawkmsg.user_fid,
                        actionType,
                        squawkmsg.user_followers
                    );
                } else if (squawkBox[i].code == 20) {
                    // REPLY
                    campaign_fid = squawkmsg.data[0];
                    uint campaign_uuid = campaignManager.campaignFidToUid(
                        campaign_fid
                    );

                    influencersManager.awardPoints(
                        campaign_uuid,
                        squawkmsg.user_fid,
                        InfluencersActions.Cast_Reply,
                        squawkmsg.user_followers
                    );
                } else if (squawkBox[i].code == 22) {
                    // MENTIONS
                    campaign_fid = squawkmsg.data[0];
                    uint campaign_uuid = campaignManager.campaignFidToUid(
                        campaign_fid
                    );

                    influencersManager.awardPoints(
                        campaign_uuid,
                        squawkmsg.user_fid,
                        InfluencersActions.Cast_Mention,
                        squawkmsg.user_followers
                    );
                } else if (squawkBox[i].code == 21) {
                    // EMBEDS
                    // NEED THIS campaign_uuid
                    uint[2] memory campaign_data = campaignAssets
                        .campaignEmbed_string(squawkmsg.embeded_string);
                    uint campaign_uuid = campaign_data[0];

                    //Check if campaign is active
                    bool campaignIsActive = campaignManager.isCampaignActive(
                        campaign_uuid
                    );

                    if (campaignIsActive) {
                        influencersManager.awardPoints(
                            campaign_uuid,
                            squawkmsg.user_fid,
                            InfluencersActions.Cast_Contains_Embed,
                            squawkmsg.user_followers
                        );
                    }
                } else if (squawkBox[i].code == 23) {
                    // TAGLINE
                    // NEED THIS campaign_uuid
                    uint[2] memory campaign_data = campaignAssets
                        .campaignEmbed_string(squawkmsg.embeded_string);
                    uint campaign_uuid = campaign_data[0];

                    //Check if campaign is active
                    bool campaignIsActive = campaignManager.isCampaignActive(
                        campaign_uuid
                    );

                    if (campaignIsActive) {
                        influencersManager.awardPoints(
                            campaign_uuid,
                            squawkmsg.user_fid,
                            InfluencersActions.Cast_Contains_Text,
                            squawkmsg.user_followers
                        );
                    }
                }

                // Do the points awarding here end
                //
            }
            lastProcessedIndex = endRange - 1;

            return true;
        }
        return false;
    }

    function getSquawkBoxLength() public view returns (uint) {
        return squawkBox.length;
    }

    function getSquawkBoxElement(
        uint index
    ) public view returns (Squawk memory) {
        require(index < squawkBox.length, "Index out of bounds");
        return squawkBox[index];
    }

    function getSquawkBoxElementRange(
        uint fromIndex,
        uint toIndex
    ) public view returns (Squawk[] memory) {
        if (squawkBox.length > 0) {
            require(
                fromIndex <= toIndex,
                "fromIndex must be less than or equal to toIndex"
            );
            require(toIndex < squawkBox.length, "toIndex is out of bounds");

            uint rangeLength = toIndex - fromIndex + 1;
            Squawk[] memory range = new Squawk[](rangeLength);

            for (uint i = 0; i < rangeLength; i++) {
                range[i] = squawkBox[fromIndex + i];
            }

            return range;
        } else {
            return new Squawk[](0); // Return an empty array if squawkBox is empty
        }
    }

    function setCampaignManager(address _campaignManager) external onlyAdmin {
        campaignManager = CampaignManager(_campaignManager);
    }

    function setInfluencersManager(
        address _influencersManager
    ) external onlyAdmin {
        influencersManager = InfluencersManager(_influencersManager);
    }

    function setCampaignAssets(address _campaignAssets) external onlyAdmin {
        campaignAssets = CampaignAssets(_campaignAssets);
    }

    function changeAdmin(address _newAdmin) external onlyAdmin {
        admin = _newAdmin;
    }

}
