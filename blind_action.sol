// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;
contract BlindAuction {
    
    struct Bid {
        bytes32 blindedBid;
        uint deposit;
    }

    address payable public beneficiary;
    uint public biddingEnd;
    uint public revealEnd;
    bool public ended;

    mapping(address => Bid) public bids;

    address public highestBidder;
    uint public highestBid;

    // Allowed withdrawals of previous bids
    mapping(address => uint) pendingReturns;

    event AuctionEnded(address winner, uint highestBid);

    // Errors that describe failures
    /// The function has been called too early.
    /// Try again at `time`.
    error TooEarly(uint time);
    
    /// The function has been called too late.
    /// It cannot be called after `time`.
    error TooLate(uint time);
    
    /// The function auctionEnd has already been called.
    error AuctionEndAlreadyCalled();
    
    /// The value entered is not matching
    error ValueNotMatching(uint value,bool fake);
    
    /// Bid Already placed 
    error AlreadyPlaced(uint value);

  
    modifier onlyBefore(uint _time) {
        if (block.timestamp >= _time) revert TooLate(_time);
        _;
    }
    modifier onlyAfter(uint _time) {
        if (block.timestamp <= _time) revert TooEarly(_time);
        _;
    }

    constructor(
        uint _biddingTime,
        uint _revealTime,
        address payable _beneficiary
    ) {
        beneficiary = _beneficiary;
        biddingEnd = block.timestamp + _biddingTime;
        revealEnd = biddingEnd + _revealTime;
    }

    
    function generateHash32(uint value, bool fake)
        public
        view
        onlyBefore(biddingEnd)
        returns (bytes32 _blindedBid)
    {
        return keccak256(abi.encodePacked(value,fake));   
    }
    
    function bid(bytes32 _blindedBid)
        public
        payable
        onlyBefore(biddingEnd)
    {
        if(bids[msg.sender].deposit != 0){revert AlreadyPlaced(msg.value);}
        bids[msg.sender] = Bid({
            blindedBid: _blindedBid,
            deposit: msg.value
        });
    }

    /// Reveal your blinded bids. You will get a refund for all
    /// correctly blinded invalid bids and for all bids except for
    /// the totally highest.
    function reveal(
        uint _value,
        bool _fake
    )
        public
        onlyAfter(biddingEnd)
        onlyBefore(revealEnd)
    {
        Bid storage currBid = bids[msg.sender];
        (uint value, bool fake) = (_value, _fake);
        if(currBid.blindedBid != keccak256(abi.encodePacked(value, fake)))
        {
            revert ValueNotMatching(value,fake);
        }
        if(!placeBid(msg.sender,value))
        {
            payable(msg.sender).transfer(value * (1 ether));
        }
        currBid.blindedBid = bytes32(0);
    }

    /// Withdraw a bid that was overbid.
    function withdraw() 
        public
        payable
    {
        uint amount = pendingReturns[msg.sender];
        if (amount > 0) {
            pendingReturns[msg.sender] = 0;
            payable(msg.sender).transfer(amount * (1 ether));
        }
    }

    /// End the auction and send the highest bid
    /// to the beneficiary.
    function auctionEnd()
        public
        payable
        onlyAfter(revealEnd)
    {
        if (ended) revert AuctionEndAlreadyCalled();
        emit AuctionEnded(highestBidder, highestBid);
        ended = true;
        beneficiary.transfer(highestBid * (1 ether));
    }


    function placeBid(address bidder, uint value) internal
            returns (bool success)
    {
        if (value <= highestBid) {
            return false;
        }
        if (highestBidder != address(0)) {
            // Refund the previously highest bidder.
            pendingReturns[highestBidder] = highestBid;
        }
        highestBid = value;
        highestBidder = bidder;
        return true;
    }
}