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

    mapping(address => bool) public isAdministrator; //accounts with sub-administrator role

    constructor() {
        admin = msg.sender;
        isAdministrator[msg.sender] = true;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "You aren't the admin");
        _;
    }
    modifier OnlyAdmins() {
        require(isAdministrator[msg.sender], "You aren't an admin");
        _;
    }

    function addSquawkData(Squawk[] memory newSquawks) external OnlyAdmins {
        for (uint i = 0; i < newSquawks.length; i++) {
            newSquawks[i].nonce = nonce;
            newSquawks[i].processed = 0; // Ensure processed is set to 0
            squawkBox.push(newSquawks[i]);
            nonce += 1;
        }
    }

    // Pass _range = 0 to process all the squawk data
    function processSquawkData(uint _range) external OnlyAdmins returns (bool) {
        if (
            squawkBox.length > 0 &&
            (lastProcessedIndex + 1 < nonce || squawkBox[0].processed == 0)
        ) {
            uint range = _range;

            if (range == 0) range = nonce - lastProcessedIndex;

            if (range > (nonce - lastProcessedIndex))
                range = nonce - lastProcessedIndex;

            uint startRange = lastProcessedIndex != 0
                ? lastProcessedIndex + 1
                : 0;
            uint endRange = lastProcessedIndex + range;

            //Award Ponts for the squawk data
            for (uint i = startRange; i < endRange; i++) {
                Squawk memory squawkmsg = squawkBox[i];

                uint campaign_fid = 0;

                // Do the points awarding here start
                if (squawkmsg.code == 14 && squawkmsg.processed == 0) {
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
                } else if (squawkmsg.code == 15 && squawkmsg.processed == 0) {
                    // UNFOLLOW
                    campaign_fid = squawkmsg.data[0];
                    uint campaign_uuid = campaignManager.campaignFidToUid(
                        campaign_fid
                    );

                    influencersManager.deductPoints(
                        campaign_uuid,
                        squawkmsg.user_fid,
                        InfluencersActions.Follow,
                        squawkmsg.user_followers
                    );
                } else if (
                    (squawkmsg.code == 16 || squawkmsg.code == 17) &&
                    squawkmsg.processed == 0
                ) {
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
                } else if (
                    (squawkmsg.code == 18 || squawkmsg.code == 19) &&
                    squawkmsg.processed == 0
                ) {
                    // REACTION DELETED
                    campaign_fid = squawkmsg.data[0];
                    uint campaign_uuid = campaignManager.campaignFidToUid(
                        campaign_fid
                    );

                    InfluencersActions actionType = squawkmsg.code == 18
                        ? InfluencersActions.Like
                        : InfluencersActions.Recast;

                    influencersManager.deductPoints(
                        campaign_uuid,
                        squawkmsg.user_fid,
                        actionType,
                        squawkmsg.user_followers
                    );
                } else if (squawkmsg.code == 20 && squawkmsg.processed == 0) {
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
                } else if (squawkmsg.code == 22 && squawkmsg.processed == 0) {
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
                } else if (squawkmsg.code == 21 && squawkmsg.processed == 0) {
                    // EMBEDS
                    // NEED campaign_uuid

                    uint[2] memory campaign_data = campaignAssets
                        .for_givenEmbedURL_get_uuidfid(
                            squawkmsg.embeded_string
                        );
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
                } else if (squawkmsg.code == 23 && squawkmsg.processed == 0) {
                    // TAGLINE
                    // NEED campaign_uuid
                    uint[2] memory campaign_data = campaignAssets
                        .for_givenTagLine_get_uuidfid(squawkmsg.embeded_string);
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

                squawkBox[i].processed = 1; // Mark as processed 1: processed, 0: not processed

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

    function toggleAdministrator(address newAdministrator) external onlyAdmin {
        require(
            admin != newAdministrator,
            "action only for toggling external administrators"
        );
        isAdministrator[newAdministrator] = !isAdministrator[newAdministrator];
    }
}
