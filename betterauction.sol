// ------------------------------------------------------------------------
// BetterAuction
//
// Decentralised open auction on the Ethereum blockchain
//
// Note: When a bidder is outbid they can top up their bid by sending more
// ether to the contract or they can get their outbid funds back by calling 
// nonHighestBidderRefund directly or by simply sending exactly 0.0001 ETH  
// to the contract.
//
// (c) Steve Dakh & BokkyPooBah 2017.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.



//changed: remove constructors and hard coded them
    // address _address1 =0xb7cf43651d8f370218cF92B00261cA3e1B02Fda0;
    // address _address2 = 0x60CE2769E5d330303Bd9Df88F7b843A40510F173;
    // address _address3 = 0x7422B53EB5f57AdAea0DdffF82ef765Cfbc4DBf0;
    // uint256 _biddingPeriod = 1800;
    // uint256 _recoveryAfterPeriod = 1000000;



// ------------------------------------------------------------------------

pragma solidity ^0.4.8;

contract BetterAuction {
    // Mapping for members of multisig
    mapping (address => bool) public members;
    // Auction start time, seconds from 1970-01-01
    uint256 public auctionStart;
    // Auction bidding period in seconds, relative to auctionStart
    uint256 public biddingPeriod;
    // Period after auction ends when the multisig proposals can withdraw all funds, relative to auctionStart
    uint256 public recoveryAfterPeriod;
    // User sends this amount to the contract to withdraw funds, 0.0001 ETH
    uint256 public constant WITHDRAWAL_TRIGGER_AMOUNT = 100000000000000;
    // Number of required signatures
    uint256 public constant REQUIRED_SIGNATURES = 2;
    // Proposal to spend
    Proposal[] public proposals;
    // Number of proposals
    uint256 public numProposals;
    // Address of the highest bidder
    address public highestBidder;
    // Highest bid amount
    uint256 public highestBid;
    // Allowed withdrawals of previous bids
    mapping(address => uint256) pendingReturns;
    // Set to true at the end, disallows any change
    bool auctionClosed;

     address _address1 =0xb7cf43651d8f370218cF92B00261cA3e1B02Fda0;
     address _address2 = 0x60CE2769E5d330303Bd9Df88F7b843A40510F173;
     address _address3 = 0x7422B53EB5f57AdAea0DdffF82ef765Cfbc4DBf0;
     uint256 _biddingPeriod = 1800;
     uint256 _recoveryAfterPeriod = 1000000;
     
     
    struct Proposal {
        address recipient;
        uint256 numVotes;
        mapping (address => bool) voted;
        bool isRecover;
    }
 
    modifier isMember {
        if (members[msg.sender] == false) throw;
        _;
    }
 
    modifier isAuctionActive {
        if (now < auctionStart || now > (auctionStart + biddingPeriod)) throw;
        _;
    }
 
    modifier isAuctionEnded {
        if (now < (auctionStart + biddingPeriod)) throw;
        _;
    }

    event HighestBidIncreased(address bidder, uint256 amount);
    event AuctionClosed(address winner, uint256 amount);
    event ProposalAdded(uint proposalID, address recipient);
    event Voted(uint proposalID, address voter);

    function BetterAuction(


    ) {
        if (_address1 == 0 || _address2 == 0 || _address3 == 0) throw;
        members[_address1] = true;
        members[_address2] = true;
        members[_address3] = true;
        auctionStart = now;
        if (_biddingPeriod > _recoveryAfterPeriod) throw;
        biddingPeriod = _biddingPeriod;
        recoveryAfterPeriod = _recoveryAfterPeriod;
    }
 
    // Users want to know when the auction ends, seconds from 1970-01-01
    function auctionEndTime() constant returns (uint256) {
        return auctionStart + biddingPeriod;
    }

    // Users want to know theirs or someones current bid
    function getBid(address _address) constant returns (uint256) {
        if (_address == highestBidder) {
            return highestBid;
        } else {
            return pendingReturns[_address];
        }
    }

    // Update highest bid or top up previous bid
    function bidderUpdateBid() internal {
        if (msg.sender == highestBidder) {
            highestBid += msg.value;
            HighestBidIncreased(msg.sender, highestBid);
        } else if (pendingReturns[msg.sender] + msg.value > highestBid) {
            var amount = pendingReturns[msg.sender] + msg.value;
            pendingReturns[msg.sender] = 0;
            // Save previous highest bidders funds
            pendingReturns[highestBidder] = highestBid;
            // Record the highest bid
            highestBid = amount;
            highestBidder = msg.sender;
            HighestBidIncreased(msg.sender, amount);
        } else {
            throw;
        }
    }
 
    // Bidders can only place bid while the auction is active 
    function bidderPlaceBid() isAuctionActive payable {
        if ((pendingReturns[msg.sender] > 0 || msg.sender == highestBidder) && msg.value > 0) {
            bidderUpdateBid();
        } else {
            // Reject bids below the highest bid
            if (msg.value <= highestBid) throw;
            // Save previous highest bidders funds
            if (highestBidder != 0) {
                pendingReturns[highestBidder] = highestBid;
            }
            // Record the highest bid
            highestBidder = msg.sender;
            highestBid = msg.value;
            HighestBidIncreased(msg.sender, msg.value);
        }
    }
 
    // Withdraw a bid that was overbid.
    function nonHighestBidderRefund() payable {
        var amount = pendingReturns[msg.sender];
        if (amount > 0) {
            pendingReturns[msg.sender] = 0;
            if (!msg.sender.send(amount + msg.value)) throw;
        } else {
            throw;
        }
    }

    // Multisig member creates a proposal to send ether out of the contract
    function createProposal (address recipient, bool isRecover) isMember isAuctionEnded {
        var proposalID = proposals.length++;
        Proposal p = proposals[proposalID];
        p.recipient = recipient;
        p.voted[msg.sender] = true;
        p.numVotes = 1;
        numProposals++;
        Voted(proposalID, msg.sender);
        ProposalAdded(proposalID, recipient);
    }

    // Multisig member votes on a proposal
    function voteProposal (uint256 proposalID) isMember isAuctionEnded {
        Proposal p = proposals[proposalID];
        
        if ( p.voted[msg.sender] ) throw;
        p.voted[msg.sender] = true;
        p.numVotes++;

        // Required signatures have been met
        if (p.numVotes >= REQUIRED_SIGNATURES) {
            if ( p.isRecover ) {
                // Is it too early for recovery?
                if (now < (auctionStart + recoveryAfterPeriod)) throw;
                // Recover any ethers accidentally sent to contract
                if (!p.recipient.send(this.balance)) throw;
            } else {
                if (auctionClosed) throw;
                auctionClosed = true;
                AuctionClosed(highestBidder, highestBid);
                // Send highest bid to recipient
                if (!p.recipient.send(highestBid)) throw;
            }
        }
    }
 
    // Bidders send their bids to the contract. If this is the trigger amount
    // allow non-highest bidders to withdraw their funds
    function () payable {
        if (msg.value == WITHDRAWAL_TRIGGER_AMOUNT) {
            nonHighestBidderRefund();
        } else {
            bidderPlaceBid();
        }
    }
}
