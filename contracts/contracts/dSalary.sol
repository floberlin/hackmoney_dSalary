// SPDX-License-Identifier: MIT
pragma solidity >=0.8.11;

/**
 * @title dSalary
 * @dev MVP Implementation for the use of a "work aggrement"-like approach for working in the web3 environment.
 */

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract dSalary is ERC1155Upgradeable, AccessControlUpgradeable, ReentrancyGuard {
    uint256 public tokenId;
    mapping(address => uint256) public isNFTHolder;
    mapping(address => uint256) public isNFTOwner;
    mapping(address => uint256) public withdrawAllowance;
    mapping(string => bool) public tokenIPFSExists;
    mapping(uint256 => string) public mappingTokenIdIPFS;
    mapping(string => uint256) public mappingIPFSTokenId;
    mapping(address => uint256[]) public addressTimeLock;
    bytes32 public constant EMPLOYEE_ROLE = keccak256("EMPLOYEE_ROLE");
    bytes32 public constant EMPLOYER_ROLE = keccak256("EMPLOYER_ROLE");
    string private _uri;

    // Intitializer for upgradable funtionality
    function initialize() public initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setURI("https://github.com/floberlin/ipfs_data/{id}.json");
    }

    // Needed for combining ERC-1155 with AccessControl
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // Static Role definitions - start

    // Any address can be whiteliste theirselfs for becoming an employer in this MVP
    function grantRoleEmployer(address reqAddr) public {
        grantRole(EMPLOYER_ROLE, reqAddr);
    }

    // Revocation of the empolyer role can only be done to the invoker of the function
    function revokeRoleEmployer() public {
        revokeRole(EMPLOYER_ROLE, msg.sender);
    }

    // Only an empolyer can grant the employee role to someonelse
    function grantRoleEmployee(address reqAddr) internal {
        require(hasRole(EMPLOYER_ROLE, msg.sender), "Caller is not an employer");
        grantRole(EMPLOYEE_ROLE, reqAddr);
    }

    // The employee can revoke their employee role, e.g. if he or she wants to quit
    function revokeRoleEmployee() public {
        revokeRole(EMPLOYEE_ROLE, msg.sender);
    }

    // Also the Employer is able to revoke the employee role from the employee. e.g. if he or she wants to terminate the contract
    function revokeRoleEmployeeExt(address reqAddr) public {
        require(hasRole(EMPLOYER_ROLE, msg.sender), "Caller is not an employer");
        grantRole(EMPLOYEE_ROLE, reqAddr);
    }

    // Static Role definitions - end

    // function for the employer to create the working aggrement
    function createWA(
        address to,
        string memory ipfsHash,
        uint256 salary,
        uint256 period
    ) public payable {
        require((salary * 1000000000000000000 * period) >= (msg.value), "Ether value too low");
        require(hasRole(EMPLOYER_ROLE, msg.sender), "Caller is not an employer");
        require(!tokenIPFSExists[ipfsHash], "IPFS CID already exists!");
        // Creation of a unique role for the ERC-1155 holder
        keccak256(addressToBytes(to));
        uint256 creationTime = block.timestamp;
        bytes memory roleName = abi.encodePacked(abi.encodePacked(to), stringToBytes(Strings.toString(creationTime)));
        isNFTOwner[to] = creationTime;
        // Granting this role to the user address
        grantRole(keccak256(roleName), to);
        // Adding the creationTime to the timelock for salary withdraws
        addressTimeLock[to].push(creationTime);
        // Saving the holder address and token id in a mapping
        isNFTHolder[to] = tokenId;
        // Also auto-granting the general empolyee role to the to_address
        grantRoleEmployee(to);
        // Saving the external ipfsHash (which holds all metadata information about the work aggrement) and the tokenId in mappings, for easy access later on
        mappingTokenIdIPFS[tokenId] = ipfsHash;
        mappingIPFSTokenId[ipfsHash] = tokenId;
        // Setting the ipfsHash to true, so no double entries can emerge
        tokenIPFSExists[ipfsHash] = true;
        // Finally minting the ERC-1155 as an NFT (amount fixed to 1)
        _mint(msg.sender, tokenId, 1, "");
        // Transfering it to the to_addess aka the employee
        safeTransferFrom(msg.sender, to, tokenId, 1, "");
        // Adding one to the tokenId for further iterations
        tokenId++;
        // Withdraw allowance for specific user
        withdrawAllowance[to] = salary;
    }

    // function for the empolyee to withdraw salary
    function withdraw() public {
        // Checking if address is an empolyee
        require(hasRole(EMPLOYEE_ROLE, msg.sender), "Caller is not an employee");
        // Recreating & checking the unique role, that should be assigned to the employee
        bytes memory cTime = stringToBytes(Strings.toString(isNFTOwner[msg.sender]));
        bytes memory roleName = abi.encodePacked(abi.encodePacked(msg.sender), cTime);
        require(hasRole(keccak256(roleName), msg.sender), "Caller is not NFT owner");
        // Checking if the empolyee is still holding the NFT
        require(balanceOf(msg.sender, isNFTHolder[msg.sender]) >= 1, "Caller is not NFT holder");

        require(
            (address(this).balance * 1000000000000000000) >= (withdrawAllowance[msg.sender] * 1000000000000000000),
            "Error: Not enought funds available to withdraw."
        );
        // Check if last salary claim is older than 30 days - set to 5 secounds for the MVP
        uint256 currentTime = block.timestamp;
        uint256 index = (addressTimeLock[msg.sender].length - 1);
        uint256 lastTime = addressTimeLock[msg.sender][index];
        uint256 minDays = (currentTime - lastTime);
        addressTimeLock[msg.sender].push(currentTime);
        require(minDays >= 7, "Error: Already claimed your salary in the last 30 days. (7 sec in the prototype)");
        payable(msg.sender).transfer(withdrawAllowance[msg.sender] * 1000000000000000000);
    }

    function tokenURI(string memory _tokenId) public pure returns (string memory) {
        return append("https://github.com/floberlin/ipfs_data/", _tokenId, ".json");
    }

    // Get ID of the ERC-155 Token based on the IPFS CID
    function getTokenId(string memory ipfsHash) public view returns (uint256) {
        return mappingIPFSTokenId[ipfsHash];
    }

    // Get assigned CID of the ERC-155 Token based on the Token ID
    function getIPFSHash(uint256 _tokenId) public view returns (string memory) {
        return mappingTokenIdIPFS[_tokenId];
    }

    // Helper functions - start
    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function stringToBytes(string memory source) internal pure returns (bytes memory result) {
        return abi.encodePacked(source);
    }

    function addressToBytes(address source) internal pure returns (bytes memory result) {
        return abi.encodePacked(source);
    }

    function append(
        string memory a,
        string memory b,
        string memory c
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b, c));
    }
    // Helper functions - end
}
