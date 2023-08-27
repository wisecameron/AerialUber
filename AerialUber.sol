//SPDX-License-Identifier: MIT

/*

    Author: Cameron Warnick | cameronwarnickbusiness@hotmail.com

    Goal: This contract uses Solidity Assembly to provide insight into 
    how storage and memory are handled by the EVM.  

    Description: AerialUber is a secure taxi service for the sky, powered by blockchain.  
    Pilots are able to service trips between different locations by creating entries into 
    the database.  For instance, create_entry("SEA", "SPO", ...data...), allowing them to 
    monetize trips for their own clients. 

    AerialUber puts passenger safety above all else, which is why pilots must pass our strict 
    security protocol. First, pilots must register their plane, along with all other pilots 
    who may potentially use the plane.  Next, the pilot must receive a medallion for their plane, which 
    verifies that maintainence has been conducted.  Finally, pilots receive individual verification, 
    providing official access to the database.  Passengers browse entries for their desired route and 
    pay Aerial Uber tokens to compensate the pilot.  
*/


pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract AerialUber is ERC20
{
    struct entry
    {
        uint64 expiration;
        uint32 ticketPrice;
        uint16 passengers;
        uint16 planeId;
    }

    struct registeredPlane
    {
        address[] pilots;
        uint256 id;
    }

    uint256 private registeredPlaneID = 1;
    uint256 private nextPilotID = 1;
    address private _owner;

    mapping(address => uint256) verifiedPilots;
    mapping(uint256 => bool) medallionHolders;
    mapping(uint256 => registeredPlane) public registeredPlanes;
    mapping(bytes32 => mapping(bytes32 => entry[])) entries;

    constructor()
    ERC20("Plane Taxi", "PT")
    {
        _owner = msg.sender;
        _mint(_owner, 100000 * 1e18);
    }

    //Step 1: Register a plane

    //Creates a new entry in registeredPlanes
    function register_plane(address[] memory pilots)
    external 
    returns(address f)
    {
        assembly
        {
            //get slot registeredPlanes[registeredPlaneID]
            mstore(0x0, sload(registeredPlaneID.slot))
            mstore(0x20, registeredPlanes.slot)
            mstore(0x0, keccak256(0x0, 0x40))

            let i := 0
            let pilotsLength := mload(pilots)

            for{}
            lt(i, pilotsLength)
            {i := add(i, 1)}
            {
                //increase length of array
                sstore(mload(0x0), add(sload(mload(0x0)), 1))

                //newPlane.pilot.push(pilots[i])
                sstore(add(keccak256(0x0, 0x20), i), mload(add(add(pilots, 0x20), mul(i, 0x20))))
                f :=  mload(add(add(pilots, 0x20), mul(i, 0x20)))
            }

            //store new id
            sstore(add(mload(0x0), 0x1), sload(registeredPlaneID.slot))
            sstore(registeredPlaneID.slot, add(sload(registeredPlaneID.slot), 1))
        }
    }

    //Step 2: Get medallion for plane
    function issue_medallion(uint256 recipientPlaneID)
    external 
    {
        assembly
        {
            //verify that the plane ID given is registered
            mstore(0x0, recipientPlaneID)
            mstore(0x20, registeredPlanes.slot)
            if iszero(sload(keccak256(0x0, 0x40)))
            {
                return(0x0, 0x0)
            }

            mstore(0x0, recipientPlaneID)
            mstore(0x20, medallionHolders.slot) 
            mstore(0x0, keccak256(0x0, 0x40))

            //if plane already has medallion, return
            if iszero(iszero(sload(mload(0x0))))
            {
                return(0x0,0x0)
            }

            //else medallionHolders[recipientPlaneID] = 1
            sstore(mload(0x0), 0x1)
        }
    }

    //Step 3: Verify individual pilots
    //Pilot must be verified before they can accept or create
    function give_verification_to_pilot(address pilot)
    external 
    {
        require(msg.sender == _owner);

        assembly
        {
            mstore(0x0, pilot)
            mstore(0x20, verifiedPilots.slot)

            let alreadyVerified := sload(keccak256(0x0, 0x40))

            if iszero(alreadyVerified)
            {
                let nextID := sload(nextPilotID.slot)
                sstore(keccak256(0x0, 0x40), nextID)
                sstore(nextPilotID.slot, add(nextID, 1))
            }

        }
    }

    //add a new entry to the database
    function create_entry_pilot(
             string memory from,
              string memory to,
               uint64 expiration,
                uint32 ticketPrice,
                 uint16 passengers,
                  uint16 planeID
                  )
    external
    {     
        bytes32 bFrom = keccak256(bytes(from));
        bytes32 bTo = keccak256(bytes(to));
        uint256 finalValue = uint256(expiration);

        address s = msg.sender;

        assembly
        {
            //check pilot is verified
            mstore(0x0, s)
            mstore(0x20, verifiedPilots.slot)
            if iszero(sload(keccak256(0x0, 0x40)))
            {
                return(0x0, 0x0)
            }

            //verify medallion
            mstore(0x20, medallionHolders.slot)
            mstore(0x0, planeID)
            if iszero(sload(keccak256(0x0, 0x40)))
            {
                return(0x0, 0x0)
            }

            //check pilot is included in medallion
            mstore(0x20, registeredPlanes.slot)
            mstore(0x0, keccak256(0x0, 0x40))

            //points to the head of registeredPlanes[planeID] -> Length of pilots array
            //must be greater than 0
            if iszero(sload(mload(0x0)))
            {
                return(0x0, 0x20)
            }

            
            //The value at this slot (ie sload(slot)) corresponds only
            //to the CURRENT length of the storage array because 
            //the entry array is dynamic.
            mstore(0x20, entries.slot)
            mstore(0x0, bFrom)
            mstore(0x20, keccak256(0x0, 0x40))
            mstore(0x0, bTo)
            
            //store the slot
            mstore(0x0, keccak256(0x0, 0x40))
            
            //configure new entry struct
            finalValue := or(shl(64, ticketPrice), finalValue)
            finalValue := or(shl(96, passengers), finalValue)
            finalValue := or(shl(112, planeID), finalValue)

            //store length of the route entry array
            mstore(0x20, sload(mload(0x0)))

            //the start of the array is the hash of the slot containing the length
            //plus the amount of preceeding elements
            let arrayStartSlot := add(keccak256(0x0, 0x20), mload(0x20))

            sstore(arrayStartSlot, finalValue)

            //increment length by 1
            sstore(mload(0x0), add(mload(0x20), 1))

        }
    }

    //passenger accepts an entry from the database.
    function accept_entry(string memory from, string memory to, uint256 index)
    external 
    {
        bytes32 bFrom = keccak256(bytes(from));
        bytes32 bTo = keccak256(bytes(to));
        uint256 userBalance = balanceOf(msg.sender);
        uint256 price;
        uint256 length = 0;
        address pilotAddress;

        assembly
        {
            //Verify that the length of the entry array is gt the index
            mstore(0x20, entries.slot)
            mstore(0x0, bFrom)
            mstore(0x20, keccak256(0x0, 0x40))
            mstore(0x0, bTo)
            let entrySlot :=  keccak256(0x0, 0x40)
            length := sload(entrySlot)
            mstore(0x0, entrySlot)

            if lt(length, index)
            {
                return(0x0, 0x0)
            }

            //Verify user balance is sufficient
            //Get to the desired storage array, isolate ticketPrice
            price := sload(add(keccak256(0x0, 0x20), index))
            let planeId := price
            price := shr(64, price)
            price := and(0xFFFFFFFF, price)
            price := mul(price, 1000000000000000000) //apply decimals
            if lt(userBalance, price)
            {
                return(0x0, 0x0)
            }

            
            //Get Plane Id
            planeId := shr(112, planeId)
            planeId := and(0xFFFF, planeId)

            //Get first pilot from the registeredPlane
            mstore(0x20, registeredPlanes.slot)
            mstore(0x0, planeId)

            //slot with length of pilots
            mstore(0x0, keccak256(0x0, 0x40))

            //verify that entry is valid
            if iszero(sload(mload(0x0)))
            {
                return(0x0, 0x0)
            }

            //take first pilot from array
            pilotAddress := sload(keccak256(0x0, 0x20)) 
            

            //Remove entry from the array

            //store last entry in the entry we want to remove
            sstore(add(keccak256(0x0, 0x20), index), sload(add(keccak256(0x0, 0x20), sub(length, 1))))

            //remove last entry
            sstore(add(keccak256(0x0, 0x20), sub(length, 1)), 0)
            
            //reduce length by 1
            sstore(entrySlot, sub(length, 1))
        }

        _transfer(msg.sender, pilotAddress, price);
    }

    function check_pilot_verification(address pilotAddress)
    external view
    returns(uint256)
    {
        return verifiedPilots[pilotAddress];
    }

    function check_id(uint256 planeId)
    external view
    returns(uint256)
    {
        return registeredPlanes[planeId].id;
    }

    function check_id_pilot(uint256 planeId)
    external view
    returns(address[] memory)
    {
        return registeredPlanes[planeId].pilots;
    }

    function check_plane_medallion(uint256 planeID)
    external view
    returns(bool)
    {
        return medallionHolders[planeID];
    }

    /*
        View an entry from the system - for a specific route
    */
    function get_entry(string memory from, string memory to, uint256 index)
    external view
    returns( entry memory )
    {
        bytes32 bFrom = keccak256(bytes(from));
        bytes32 bTo = keccak256(bytes(to));

        return(entries[bFrom][bTo][index]);
    }

    /*
        View the entire entry array for a specific route
    */
    function get_entries(string memory from, string memory to)
    external view
    returns( entry[] memory )
    {
        bytes32 bFrom = keccak256(bytes(from));
        bytes32 bTo = keccak256(bytes(to));

        return(entries[bFrom][bTo]);
    }

    function entry_length(string memory from, string memory to)
    external view
    returns(uint256)
    {
        bytes32 bFrom = keccak256(bytes(from));
        bytes32 bTo = keccak256(bytes(to));
        return(entries[bFrom][bTo].length);
    }
}