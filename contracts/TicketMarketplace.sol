// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ITicketNFT} from "./interfaces/ITicketNFT.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TicketNFT} from "./TicketNFT.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol"; 
import {ITicketMarketplace} from "./interfaces/ITicketMarketplace.sol";
import "hardhat/console.sol";

contract TicketMarketplace is ITicketMarketplace {
    // your code goes here (you can do it!)
    address public nftContract;
    address public ERC20Address;
    address public owner;
    uint128 public currentEventId = 0;

    constructor(address _ERC20Address) {
        TicketNFT ticketNFT = new TicketNFT();
        nftContract = address(ticketNFT);
        ERC20Address = _ERC20Address;
        owner = msg.sender;
    }

    struct EventInfo {
        uint128 nextTicketToSell;
        uint128 maxTickets;
        uint256 pricePerTicket;
        uint256 pricePerTicketERC20;
    }
    mapping(uint128 => EventInfo) public events;

    function createEvent(uint128 maxTickets, uint256 pricePerTicket, uint256 pricePerTicketERC20) external {
        require(msg.sender == owner, "Unauthorized access");

        uint128 eventId = currentEventId;
        events[eventId] = EventInfo(
            0, maxTickets, pricePerTicket, pricePerTicketERC20
        );
        currentEventId++;

        emit EventCreated(eventId, maxTickets, pricePerTicket, pricePerTicketERC20);
    }

    function setMaxTicketsForEvent(uint128 eventId, uint128 newMaxTickets) external {
        require(msg.sender == owner, "Unauthorized access");

        if (newMaxTickets < events[eventId].maxTickets) {
            revert("The new number of max tickets is too small!");
        }
        events[eventId].maxTickets = newMaxTickets;

        emit MaxTicketsUpdate(eventId, newMaxTickets);
    }

    function setPriceForTicketETH(uint128 eventId, uint256 price) external {
        require(msg.sender == owner, "Unauthorized access");
        events[eventId].pricePerTicket = price;
        emit PriceUpdate(eventId, price, "ETH");
    }

    function setPriceForTicketERC20(uint128 eventId, uint256 price) external {
        require(msg.sender == owner, "Unauthorized access");
        events[eventId].pricePerTicketERC20 = price;
        emit PriceUpdate(eventId, price, "ERC20");
    }

    function setERC20Address(address newERC20Address) external {
        require(msg.sender == owner, "Unauthorized access");
        ERC20Address = newERC20Address;
        emit ERC20AddressUpdate(newERC20Address);
    }

    function buyTickets(uint128 eventId, uint128 ticketCount) payable external {
        EventInfo storage curr_event = events[eventId];
        
        if (ticketCount > type(uint256).max / curr_event.pricePerTicket) {
            revert("Overflow happened while calculating the total price of tickets. Try buying smaller number of tickets.");
        }

        if (msg.value < curr_event.pricePerTicket * ticketCount) {
            revert("Not enough funds supplied to buy the specified number of tickets.");
        }

        if (curr_event.nextTicketToSell + ticketCount > curr_event.maxTickets) {
            revert("We don't have that many tickets left to sell!");
        }
 
        // mint NFT for each ticket
        for (uint128 i = 0; i < ticketCount; i++) {
            uint256 ticketId = (uint256(eventId) << 128) + curr_event.nextTicketToSell;
            ITicketNFT(nftContract).mintFromMarketPlace(msg.sender, ticketId);
            curr_event.nextTicketToSell++;
        }
        
        emit TicketsBought(eventId, ticketCount, "ETH");
    }

    function buyTicketsERC20(uint128 eventId, uint128 ticketCount) external {
        EventInfo storage curr_event = events[eventId];
        
        if (ticketCount > type(uint256).max / curr_event.pricePerTicketERC20) {
            revert("Overflow happened while calculating the total price of tickets. Try buying smaller number of tickets.");
        }

        uint256 ticketCost = curr_event.pricePerTicketERC20 * ticketCount;
        if (IERC20(ERC20Address).balanceOf(msg.sender) < ticketCost) {
            revert("Not enough funds is on the account to buy the specified number of tickets.");
        }

        if (curr_event.nextTicketToSell + ticketCount > curr_event.maxTickets) {
            revert("We don't have that many tickets left to sell!");
        }

        // mint NFT for each ticket
        for (uint128 i = 0; i < ticketCount; i++) {
            uint256 ticketId = (uint256(eventId) << 128) + curr_event.nextTicketToSell;
            ITicketNFT(nftContract).mintFromMarketPlace(msg.sender, ticketId);
            curr_event.nextTicketToSell++;
        }

        // transfer ERC20 tokens to current contract
        IERC20(ERC20Address).transferFrom(msg.sender, address(this), ticketCost);

        emit TicketsBought(eventId, ticketCount, "ERC20");
    }
}