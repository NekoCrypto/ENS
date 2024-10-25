// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title The ENS contract registers domains and binds them to an EVM address
/// @notice Users can register ENS domains to their addresses
/// @dev Contract is in development
contract ENS {
    struct EnsBuyer {
        address buyer;
        uint timestamp;
        uint value;
        uint yearsReg;
    }

    address public owner;
    uint public constant MIN_YEARS = 1;
    uint public constant MAX_YEARS = 10;
    uint private constant ONE_YEAR = 31_536_000; // One year in seconds

    uint public priceOneYear = 1e18; // Initial price per year
    uint public renewalMul = 75; // Renewal multiplier as a percentage (75%)

    mapping(address => EnsBuyer) public buyersDB;
    mapping(bytes32 => address) public ensUsers;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not Owner!");
        _;
    }

    modifier yearsLimit(uint _years) {
        require(_years >= MIN_YEARS && _years <= MAX_YEARS, "Min 1 year - Max 10 years");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /// @notice Registers an ENS domain for the caller
    /// @param _ensDomain The domain to register, passed as bytes32
    /// @param _yearsReg Number of years for which the domain is registered
    function buyENS(bytes32 _ensDomain, uint _yearsReg) public payable yearsLimit(_yearsReg) {
        require(msg.value >= priceOneYear * _yearsReg, "Insufficient payment for registration");

        address currentOwner = ensUsers[_ensDomain];
        if (currentOwner != address(0)) {
            require(isExpired(currentOwner), "ENS domain already registered and active");
            delete buyersDB[currentOwner];
            delete ensUsers[_ensDomain];
        }

        ensUsers[_ensDomain] = msg.sender;
        buyersDB[msg.sender] = EnsBuyer({
            buyer: msg.sender,
            timestamp: block.timestamp,
            value: msg.value,
            yearsReg: _yearsReg
        });
    }

    /// @notice Extends the registration period for an ENS domain
    /// @param _ensDomain The domain to renew
    /// @param _yearsExp Number of additional years for renewal
    function expandENS(bytes32 _ensDomain, uint _yearsExp) public payable yearsLimit(_yearsExp) {
        require(ensUsers[_ensDomain] == msg.sender, "Not owner of ENS");

        EnsBuyer storage existingBuyer = buyersDB[msg.sender];
        uint renewalPrice = priceOneYear * _yearsExp * renewalMul / 100;
        require(msg.value >= renewalPrice, "Insufficient funds for renewal");

        if (isExpired(msg.sender)) {
            existingBuyer.timestamp = block.timestamp;
        }
        existingBuyer.yearsReg += _yearsExp;
        existingBuyer.value += msg.value;
    }

    /// @notice Checks if the ENS domain for an address has expired
    /// @param user The address of the ENS domain owner
    /// @return True if the domain is expired, false otherwise
    function isExpired(address user) internal view returns (bool) {
        EnsBuyer memory existingBuyer = buyersDB[user];
        uint expiryTime = existingBuyer.timestamp + (existingBuyer.yearsReg * ONE_YEAR);
        return block.timestamp > expiryTime;
    }

    /// @notice Withdraws all ETH from the contract to the owner’s address
    function withdrawAll() public onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    /// @notice Sets the price per year for ENS registration
    /// @param _price The new price per year in wei
    function setPriceOneYear(uint _price) public onlyOwner {
        priceOneYear = _price;
    }

    /// @notice Sets the renewal multiplier percentage
    /// @param _multiplier The new renewal multiplier (e.g., 75 for 75%)
    function setRenewalMultiplier(uint _multiplier) public onlyOwner {
        require(_multiplier > 0 && _multiplier <= 100, "Multiplier must be between 1 and 100");
        renewalMul = _multiplier;
    }

    /// @notice Retrieves the address bound to a given ENS domain
    /// @param _ensDomain The ENS domain to look up
    /// @return The address associated with the ENS domain
    function getEnsUser(bytes32 _ensDomain) public view returns (address) {
        return ensUsers[_ensDomain];
    }
}
