//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CampaignManager.sol";
import {CampaignState, Campaign} from "./CampaignManager.sol";

contract Squawk {
    CampaignManager public campaignManager;

    address public admin;
    uint public nonce;
    uint public lastProcessedIndex;

    uint[][] public squawkBox;

    constructor() {
        admin = msg.sender;

        squawkBox.push([1, 2, 3, nonce, 0]); //the last-1 uint is 0 for not processed and 1 for processed //the last uint is nonce
        squawkBox.push([4, 5, 6, 7, 8, 9, nonce + 1, 0]);
        nonce += 2;
    }

    modifier OnlyAdmin() {
        require(msg.sender == admin, "You aren't the admin");
        _;
    }

    // Function to add multiple nested arrays to the existing array
    function add_SquawkData(uint[][] memory newElements) external OnlyAdmin {
        for (uint i = 0; i < newElements.length; i++) {
            uint elementLength = newElements[i].length;

            uint[] memory temp = new uint[](elementLength + 2);

            for (uint j = 0; j < elementLength; j++) {
                temp[j] = newElements[i][j];
            }
            temp[elementLength] = nonce;
            nonce += 1;

            squawkBox.push(temp);
        }
    }

    //pass _range = 0 to process all the squawk data
    function processSquawkData(uint _range) external returns (bool) {
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
                uint elementLength = squawkBox[i].length;
                squawkBox[i][elementLength - 1] = 1; // Mark as processed 1: processed, 0: not processed

                //Do the points awarding here
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
    ) public view returns (uint[] memory) {
        require(index < squawkBox.length, "Index out of bounds");
        return squawkBox[index];
    }

    function getSquawkBoxElementRange(
        uint fromIndex,
        uint toIndex
    ) public view returns (uint[][] memory) {
        if (squawkBox.length > 0) {
            require(
                fromIndex <= toIndex,
                "fromIndex must be less than or equal to toIndex"
            );
            require(toIndex < squawkBox.length, "toIndex is out of bounds");

            uint rangeLength = toIndex - fromIndex + 1;
            uint[][] memory range = new uint[][](rangeLength);

            for (uint i = 0; i < rangeLength; i++) {
                range[i] = squawkBox[fromIndex + i];
            }

            return range;
        } else {
            return new uint[][](0); // Return an empty array if squawkBox is empty
        }
    }

    function setCampaignManager(address _campaignManager) external OnlyAdmin {
        campaignManager = CampaignManager(_campaignManager);
    }

    function changeAdmin(address _newAdmin) external OnlyAdmin {
        admin = _newAdmin;
    }
}

//Do not forget in all the below we add 1 element as nonce and 1 more (the last element) as 0 for unprocessed and 1 for processed
// for_sc = [created_at, 14, user_fid, user_followed, user_followers];                                                    //FOLLOW
// for_sc = [created_at, 15, user_fid, user_unfollowed, user_followers];                                                  // UNFOLLOW
// for_sc = [created_at, (data.reaction_type === 1? 16 : 17), user_fid, data.cast.hash, cast_author_fid, user_followers]. // handle_Reaction_Created
// for_sc = [created_at, (data.reaction_type === 1? 18 : 19), user_fid, data.cast.hash, cast_author_fid, user_followers]  // handle_Reaction_Deleted
// for_sc = [created_at, 20, user_fid, data.hash,  data.parent_hash, replyToAuthorFid, user_followers]                    // handle_CastCreated - REPLY
// for_sc = [created_at, 21, data.author.fid, data.hash, embed, user_followers]                                           // handle_CastCreated - EMBEDS
// for_sc = [created_at, 22, user_fid, data.hash, mentionedFid, user_followers]                                           // handle_CastCreated - MENTIONS
// for_sc = [created_at, 23, data.author.fid, data.hash, tagline, user_followers ]                                        // handle_CastCreated - TAGLINES
