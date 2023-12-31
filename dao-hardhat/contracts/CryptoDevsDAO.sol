// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

//Interfaces

interface IFakeNFTMarketplace {
    
    function purchase(uint256 _tokenId) external payable;

    function getNftPrice() external view returns (uint256);

    function available(uint256 _tokenId) external view returns (bool);

}

interface ICryptoDevsNFT {
        
    function balanceOf(address owner) external view returns (uint256);

    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);
}


contract CryptoDevsDAO is Ownable {
    
    struct Proposal {
        uint256 nftTokenId;
        uint256 deadline;
        uint256 yayVotes;
        uint256 nayVotes;
        bool executed;

        // voters - a mapping of CryptoDevsNFT tokenIDs to booleans indicating whether that NFT has already been used to cast a vote or not
        mapping(uint256 => bool) voters;
    }

    enum Vote {
        YAY, // YAY = 0
        NAY // NAY = 1
    }

    mapping (uint256 => Proposal) public proposals;

    uint256 public numProposals;

    ICryptoDevsNFT cryptoDevsNFT;
    IFakeNFTMarketplace nftMarketplace;


    // Create a modifier which only allows a function to be
    // called by someone who owns at least 1 CryptoDevsNFT
    modifier nftHolderOnly() {
        require(cryptoDevsNFT.balanceOf(msg.sender) > 0, "NOT_A_DAO_MEMBER");
        _;
    }

    modifier activeProposalOnly(uint256 proposalIndex) {
        require(
            proposals[proposalIndex].deadline > block.timestamp,
            "DEADLINE_EXCEEDED"
        );
        _;
    }

    modifier inactiveProposalOnly(uint256 proposalIndex) {
        require(proposals[proposalIndex].deadline <= block.timestamp, "DEADLINE_NOT_EXCEEDED");
        require(proposals[proposalIndex].executed == false, "PROPOSAL_ALREADY_EXECUTED");
        _;
    }


    constructor (address _cryptoDevsNFT, address _nftMarketplace) payable {
        cryptoDevsNFT = ICryptoDevsNFT(_cryptoDevsNFT);
        nftMarketplace = IFakeNFTMarketplace(_nftMarketplace);
    }

    function createProposal(uint256 _nfttokenId) external nftHolderOnly returns(uint256) {
        
        require(nftMarketplace.available(_nfttokenId), "NFT not for sale!");
        
        Proposal storage proposal = proposals[numProposals];
        proposal.nftTokenId = _nfttokenId; 
        proposal.deadline = block.timestamp + 5 minutes;

        numProposals ++;

        return numProposals - 1;
    }


    function voteOnProposal(uint256 proposalIndex, Vote vote) 
        external 
        nftHolderOnly 
        activeProposalOnly(proposalIndex) 
    {
        Proposal storage proposal = proposals[proposalIndex];

        uint256 voterNFTBalance = cryptoDevsNFT.balanceOf(msg.sender);
        uint256 numVotes = 0;

        for (uint256 i = 0; i < voterNFTBalance; i++) {
            
            uint256 tokenId = cryptoDevsNFT.tokenOfOwnerByIndex(msg.sender, i);

            if (proposal.voters[tokenId] == false) {
                numVotes ++;
                proposal.voters[tokenId] == true;
            }
        }

        require(numVotes > 0, "Already Voted!");

        if (vote == Vote.YAY) {
            proposal.yayVotes += numVotes;
        }

        else {
            proposal.nayVotes += numVotes;
        }
    }


    function executeProposal(uint256 proposalIndex) 
        external 
        nftHolderOnly 
        inactiveProposalOnly(proposalIndex)
    {
        Proposal storage proposal = proposals[proposalIndex];

        if (proposal.yayVotes > proposal.nayVotes) {
            uint256 nftPrice = nftMarketplace.getNftPrice();
            require(address(this).balance >= nftPrice, "NOT_ENOUGH_FUNDS");
            nftMarketplace.purchase{value: nftPrice}(proposal.nftTokenId);
        }

        proposal.executed = true;
    }


    function withdrawEther() external onlyOwner {
        uint256 amount = address(this).balance;
        require(amount > 0, "Nothing to withdraw, contract balance empty");
        (bool sent, ) = msg.sender.call{value: amount}("");
        require(sent, "FAILED_TO_WITHDRAW_ETHER");
    }

    receive() external payable {}
    fallback() external payable {}
}