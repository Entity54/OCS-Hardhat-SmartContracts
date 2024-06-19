# Smart contract documentation

THe below aims to provide a brief explanation of the smart contracts

## CampaignManager.sol

### Step 1 createCampaign - USER

Provide a description string for the campaign, the Farcaster FID of the comapny Farcaster account, the startTime when to start the capmaign and the endTime when to finsih the campaign. Provide also the campaign marking array. This array is matched 1-to-1 with

```
  struct InfluencerActionsPoints {
        uint follow_points;
        uint like_points;
        uint recast_points;
        uint cast_mention_points;
        uint cast_contains_text_points;
        uint cast_contains_embed_points;
        uint cast_reply_points;
    }
```

and predetermines how many points an influencer will be awarded for a specific action.

Given this input a new campaign struct

```
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
        address[] influencersFids2;
        uint timestamp;
        uint posId;
    }
```

is created. The msg.sender is the comapign owner, the intial state is CampaignState.Pending from enumeration

```
    enum CampaignState {
        Pending,
        Active,
        Expired
    }
```

the budget is the msg.value ETH that the cmapaign owner transferred when calling this function and this is the total amount of ETH to be distributed to capmaing aprticipants and our platformn

The array of influencersFids is by default empty but it will hold the FIDs of registered Influencers for this campaign.

Each campaign has a unique identifier uuid

We push this cmapiagn uuid to the pendingCampaignUIDs array and in the mapping

```
mapping(uint => Campaign) public campaigns; // uuid => Campaign
```

and the campaing markign in the mapping

```
 mapping(uint => uint[7]) public campaignPointMarking;
```

Finally the campaign deposit is registered in

```
mapping(address => uint) public campaignBalances;
```

### Step 2 - checkPendingCampainStatus

When this function is called with the uuid of a campaign that exists in pendingCampaignUIDs, it checks whether it is time for the capmaign to start, in which case it pushes the campaign to activeCampaignUIDs and removes it from pendingCampaignUIDs. It will also amend the campaign state to CampaignState.Active and

```
 isCampaignActive[_uuid] = true;
```

### Step 3 - checkActiveCampainStatus

When this function is called with the uuid of a campaign that exists in activeCampaignUIDs, it checks whether it is time for the capmaign to finish, in which case it pushes the campaign to expiredCampaignUIDs and removes it from activeCampaignUIDs. It will also amend the campaign state to CampaignState.Expired and

```
 isCampaignActive[_uuid] = false;
```

### Step 4 - calculateDistributions

When this function is called with the uuid of a campaign that exists in expiredCampaignUIDs it will

1. calcualte budget to distribute after deducting platfrom fees
2. use the total points (score) that each Infuencer Fid has accummulated for this campaign throughout the duration of the campaign to calculate the funds to be allocated for each campaign influencer. These are saved in the campaign struct field distributions
3. deletes the campaign from expiredCampaignUIDs and adds it to the readyForPaymentçampaignUIDs

### Step 5 - makePayments

When this function is called with the uuid of a campaign that exists in readyForPaymentçampaignUIDs it will

1. use the calculated amounts of wei stored in the campaign struct in the field distributions and the field influencersFids to make payments to infuencers ethereum accounts
2. allocate fees to the platform balance ledger
3. ensure isCampaignPaymentsComplete[_uuid] = true; payments are done

### Step 6 - registerInfluencerForCampaign

This function cannot be called directly. Only the "influencersManager" smart contract can call it

When called with a uuid for a campaign and with an fid of an influencer the fid is added in the "campaign.influencersFids" struct. In this way we recognise active campaign participants eligible for points allocation.

<br>
<br>
<br>

## InfluencersManager.sol

### Step 1 registerInfluencer

When an infuencer calls this function with his Farcaster FID then

1. Can only be registered if not already registred
2. His fid is pushed in influencersUIDs
3. In the mapping
   `mapping(uint => address) public influencerAddress;`
   we pair his fid with the msg.sender

4. In the mapping
   `mapping(address => uint) public influencerFids`
   we pair his msg.sender with his fid

> NOTE: TO ENSURE THAT MSG.SENDER THAT REGISTERS WITH AN FID IS TRUTHFUL WE USE CHAINLINK FUNCTION TO CALL FARCASTER WITH THE PROVIDED ADDRRESS AND ENSURE THIS AS A VERIFIED ADDRESS OF A FARCASTER ACCOUNT COMES BACK WITH THE SAME FID

### Step 2 registerToCampaign

The influnecer calling this function (from his registered wallet) with teh campaing_uui will result in calling registerInfluencerForCampaign of the CampaignManager.sol and therefore register to thsi campaing
It is important to emphasize that:

1.  campaignManager.isCampaignActive(campaign_uuid) ensures that the campaign is active i.e. cannot regster on a pendign or expired campaing
2.  "require(!isCampaignInfuencer[campaign_uuid][influencerFid],"Influencer not in campaign");"
    ensures that the influencer is not already registered fro the campaign

<br>

## General Notes

1. The enumeration

```
enum InfluencersActions {
    Follow,
    Like,
    Recast,
    Cast_Mention,
    Cast_Contains_Text,
    Cast_Contains_Embed,
    Cast_Reply
}
```

describes all possible actions an Influencer can make that are eligible for point allocation for a campain

2. The struct

```
    struct Influencer {
        uint fid;
        address custodyAddress;
        address verifiedAddress;
        uint spammerFactor;
        uint posId;
    }
```

Holds an influencer account details

> Points allocated to an influencer when he/she performs certain action is the product of the score allocated by the campain owner for the specific action at the initiation of the campaing x number of followers the infuencer has.

The purpose of this is to award more points to an infuencer that likes or re-casts a campaign marketing asset (as an exmaple) that has a lot of followers e.g. 1000 followers compare to an infuencer with 10 followers

However the infuencer shoudl be cautious about two aspects:

1. Negating an action e.g. unliking or delting a cast etc. will deduct the campain score points for the action x number of followers x spammerFactor.

If the infuencer has the same amount of followers when he liked or recasted then the same amount of points will be deducted. If the infuencer has in the meantime increased his followers, since he now had more followers, more points will be deducted. This is done to ensure that any action that targetted in maximum efficiemcy of the marketign campaign has always maximum effect and no gaming the process is in place

2. There is a case of a bad actor that fabricates followers e.g. shows he has 1000 followers. Performing an action, points as explained above will be credited to the infuencer's account.

If the infuencer then instructs his/her fabricated followers to unfollow him e.g. ends up with only 500 followers, and then negates an action e.g. unlike, delete a re-cast then the points deducted will be far less than what he received when he/she liked , re-casted.

The bad actor could then instruct the fabricated followers to follow his/her accoutn again and by performing a like, re-cast end up in a big surplus of points for trying to game the system

For this reason we have used in the points to be deducted calculation the spammerFactor which for each influencer starts at 1

Eveytime the infuencer negates an action the spammerFactor doubles. Soon it becomes so big that the infuencer points scores resets to 0 and he/she has to start from scratch.

> The spammerFactor scaling formula is under further research to ensure that an infuencer is not penalised unfairly but also enuring the presence of a healthy, ethical and efficient marketing platform

> Note that the spammerFactor of an infunecer affects his whole presence on the platform for all the campaigns he participates. Further reseatch is under way to ensure a bad actor cannot game the system but misbehaving across multiple campaigns.

4. The mapping

```
 mapping(uint => mapping(uint => uint[8])) public campaignScores;
```

points for a given campaign uuid and influencer fid to the influencer's points array that follows the schema below

```
campaign_uuid => fid => uint[8]
[follow_points,like_points,recast_points,cast_mention_points,cast_contains_text_points,cast_contains_embed_points,cast_reply_points,total_points]
```

```
mapping(uint => uint) public total_campaign_score; //campaign_uuid => total points from all influencers
```

total points from all influencers for a campaign with a specific uuid

### Step 3 awardPoints

This function can only be called by the admin

When it is called for a given campaign uuid, influencer fid and an actioType and number of Influencer Followers it calculates the amount of points to be allocated to the influencer

1. There is a check that influencer is registered for the campaign
2. The campaign score array is loaded
3. The actionType has to be any valid influencer actions as described in enum InfluencersActions
4. The base points for a given category are derived from the campaign marking array for this category and is then multiplied by the current influencer number of followers to derive the total points to be added to this category of actionType and to the overall points of the infuencer

### Step 4 deductPoints

This function is the reversal of the award Points in case an influencer negates a previous positive action for the marketing campaig e.g. he unfollows, unlikes, deletes a cast.

The total number of points deducted is affected by the campign score for the action, the infuencer's number of followers and the infuencer spammerFactor

<br>
<br>
<br>

### Diary

1. Create a campaign - provide specs and deposit funds - register company fid DONE
2. check state of the campaigne for pending PENDING -> ACTIVE DONE
3. check state of the campaigne for active ACTIVE -> EXPIRED DONE

4. register infuencer, fid , address - TODO MORE

5. award_points DONE
6. deduct points DONE
7. calculate distributions and platform fees DONE
8. make payments DONE
9. Enure Platform fees can be withdrawn DONE

//TODO

1. register company cast hash  
   2.. register asset , author address

<br>
<br>
<br>
