//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CampaignManager.sol";
import {CampaignState, Campaign} from "./CampaignManager.sol";

contract CampaignAssets {
    CampaignManager public campaignManager;
    address public admin;

    struct WebhookData {
        uint campaign_uuid;
        uint campaing_fid;
        uint cast_created_parent_author_fids;
        string cast_created_text;
        uint cast_created_mentioned_fids;
        string cast_created_parent_embeds;
        uint follow_created_target_fids;
        uint follow_deleted_target_fids;
        uint reaction_created_target_fids;
        uint reaction_deleted__target_fids;
        uint posId;
    }

    uint[] public campaignUIDs;
    uint[] public activeCampaignFIDs;

    mapping(uint => string) public campaignTagLine; // uuid => tagline
    mapping(uint => string) public campaignEmbed; // uuid => emded url
    mapping(uint => bool) public campaignHasRegisteredWebhookdata;
    mapping(uint => WebhookData) public campaignWebhookdata;

    mapping(address => bool) public isAdministrator; //accounts with sub-administrator role

    constructor() {
        admin = msg.sender;
    }

    modifier OnlyAdmin() {
        require(msg.sender == admin, "You aren't the admin");
        _;
    }
    modifier OnlyAdmins() {
        require(isAdministrator[msg.sender], "You aren't an admin");
        _;
    }

    function addTo_activeCampaignFids(uint campaign_fid) external {
        activeCampaignFIDs.push(campaign_fid);
    }

    function deleteFrom_activeCampaignFids(uint campaign_fid) external {
        bool elemnentfound = false;
        for (uint i = 0; i < activeCampaignFIDs.length; i++) {
            if (activeCampaignFIDs[i] == campaign_fid) {
                activeCampaignFIDs[i] = activeCampaignFIDs[
                    activeCampaignFIDs.length - 1
                ];
                elemnentfound = true;
                break;
            }
        }
        if (elemnentfound) {
            activeCampaignFIDs.pop();
        }
    }

    function registerWebhookData(
        uint _campaign_uuid,
        uint _campaing_fid,
        uint _cast_created_parent_author_fids,
        string memory _cast_created_text,
        uint _cast_created_mentioned_fids,
        string memory _cast_created_parent_embeds,
        uint _follow_created_target_fids,
        uint _follow_deleted_target_fids,
        uint _reaction_created_target_fids,
        uint _reaction_deleted__target_fids
    ) external {
        if (!campaignHasRegisteredWebhookdata[_campaign_uuid]) {
            Campaign memory campaign = campaignManager.getCampaign(
                _campaign_uuid
            );
            if (
                campaign.owner == msg.sender &&
                (campaign.state == CampaignState.Pending ||
                    campaign.state == CampaignState.Active)
            ) {
                campaignHasRegisteredWebhookdata[_campaign_uuid] = true;

                campaignWebhookdata[_campaign_uuid] = WebhookData({
                    campaign_uuid: _campaign_uuid,
                    campaing_fid: _campaing_fid,
                    cast_created_parent_author_fids: _cast_created_parent_author_fids,
                    cast_created_text: _cast_created_text,
                    cast_created_mentioned_fids: _cast_created_mentioned_fids,
                    cast_created_parent_embeds: _cast_created_parent_embeds,
                    follow_created_target_fids: _follow_created_target_fids,
                    follow_deleted_target_fids: _follow_deleted_target_fids,
                    reaction_created_target_fids: _reaction_created_target_fids,
                    reaction_deleted__target_fids: _reaction_deleted__target_fids,
                    posId: campaignUIDs.length
                });

                campaignUIDs.push(_campaign_uuid);

                campaignTagLine[_campaign_uuid] = _cast_created_text;
                campaignEmbed[_campaign_uuid] = _cast_created_parent_embeds;
            }
        }
    }

    function deleteWebhookData(uint _campaign_uuid) public {
        Campaign memory campaign = campaignManager.getCampaign(_campaign_uuid);

        WebhookData memory _campaignWHdata = campaignWebhookdata[
            _campaign_uuid
        ];

        if (
            campaign.state == CampaignState.Paid ||
            campaign.state == CampaignState.Void
        ) {
            uint index = _campaignWHdata.posId;
            uint lastPosition = campaignUIDs.length - 1;
            if (index < lastPosition) {
                uint lastItemValue = campaignUIDs[lastPosition];
                campaignUIDs[index] = lastItemValue;
                campaignWebhookdata[lastItemValue].posId = index;
            }
            campaignUIDs.pop();

            delete campaignWebhookdata[_campaign_uuid];
            delete campaignTagLine[_campaign_uuid];
            delete campaignEmbed[_campaign_uuid];
        }
    }

    function getCampaignWebhookData(
        uint campaign_uuid
    ) external view returns (WebhookData memory) {
        return campaignWebhookdata[campaign_uuid];
    }

    function get_campaignUIDs() external view returns (uint[] memory) {
        return campaignUIDs;
    }

    function get_activeCampaignFIDs() external view returns (uint[] memory) {
        return activeCampaignFIDs;
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
