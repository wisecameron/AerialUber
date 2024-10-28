<div align="center">
  <img src="AerialUberIMG.png" height="500">
</div>

<div align="center">
  <br>
  <br>
  <p>
    <b>Aerial Uber: Solidity Assembly Project!</b>
  </p>
  <p>
     <i>Aerial Uber is a system that allows verified pilots to earn ERC20 tokens by 
     accepting customer-supplied jobs listed in the system.  The entire system is implemented in Solidity assembly, making it a great reference for developers trying to better learn Yul.  
     </i>
  </p>
  <p>

  </p>
</div>

---

## Highlights ✨
* Built in Yul
* Covers tricky examples such as indexing into mapping(bytes32 => mapping(bytes32 => entry[])) entries
* Fully working, optimized system


## Examples 🖍
```
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
```

---
<div align="center">
	<b>
		<a href="https://www.npmjs.com/package/get-good-readme">File generated with get-good-readme module</a>
	</b>
</div>
