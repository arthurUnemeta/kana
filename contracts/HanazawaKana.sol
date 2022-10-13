// SPDX-License-Identifier: MIT

import { ERC721A } from "./ERC721A.sol";
import { Ownable } from "./Ownable.sol";
import { MerkleProof } from "./MerkleProof.sol";

pragma solidity >=0.8.17 <0.9.0;

error AlreadyClaim();
error CallerIsContract();
error CannotMintFromContract();
error InsufficientFunds();
error InvalidMintAmount();
error InvalidMintPriceChange();
error InvalidSalesPhaseChange();
error InvalidWithdrawalAmount();
error MintAmountExceedsSupply();
error WithdrawalFailed();
error WrongSalesPhase();
error InvalidMerkleProof();
error MintAmountExceedsUserAllowance();

contract HanazawaKanaNFT is ERC721A, Ownable {

    uint48 public constant MAX_SUPPLY = 6666;
    uint256 public  PUBLIC_PRICE = 0.08 ether;
    uint256 public  ALLOW_LIST_PRICE = 0.08 ether;
    uint48 public Supply = 0;
    mapping(address => bool) public FreelistClaimed;
    uint48 public constant SECTION_BITMASK = 15;
    uint48 public constant DISTRICT_BITMASK = 4095;
    uint8 public currSalesPhase = 8;
    string public metadataURI;
    bytes32 private _merkleRoot;
    constructor() ERC721A("HanazawaKanaNFT", "KANA") {}

    //modifiers
    modifier CallerIsUser() {
        if (tx.origin != msg.sender) revert CallerIsContract();
        _;
    }
    modifier mintPublic(uint48 _mintAmount) {
        require(
            Supply + _mintAmount <= MAX_SUPPLY,
            "Max supply exceeded!"
        );
        _;
    }

    function FreeMint(bytes32[] calldata _proof, uint48 _inputConfig) 
        external
        CallerIsUser
    {
        uint48 amountAllowed = (_inputConfig >> 16) & SECTION_BITMASK;
        uint48 userSalesPhase = _inputConfig >> 20;
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender,amountAllowed,userSalesPhase));
        if (!MerkleProof.verifyCalldata(_proof, _merkleRoot, leaf)) revert InvalidMerkleProof();
        if (userSalesPhase != currSalesPhase) revert WrongSalesPhase();
        uint48 Amount = _inputConfig & DISTRICT_BITMASK;
        if (Amount == 0) revert InvalidMintAmount();
        if(FreelistClaimed[_msgSender()]) revert AlreadyClaim();
        FreelistClaimed[_msgSender()] = true;
        _mint(msg.sender, Amount);
        Supply += Amount;
    }

    function WhitelistMint(bytes32[] calldata _proof, uint48 _inputConfig)
        external
        payable
        CallerIsUser
    {
        uint48 amountAllowed = (_inputConfig >> 16) & SECTION_BITMASK;
        uint48 userSalesPhase = _inputConfig >> 20;
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, amountAllowed,userSalesPhase));
        if (!MerkleProof.verifyCalldata(_proof, _merkleRoot, leaf)) revert InvalidMerkleProof();
        if (userSalesPhase != currSalesPhase) revert WrongSalesPhase();
        uint48 Amount = _inputConfig & DISTRICT_BITMASK;
        if (Amount == 0) revert InvalidMintAmount();

        uint64 userAux = _getAux(msg.sender);
        uint64 allowlistMinted = (userAux >> 4) & SECTION_BITMASK;
        if (allowlistMinted + Amount > amountAllowed) revert MintAmountExceedsUserAllowance();
        
        if (msg.value < Amount * ALLOW_LIST_PRICE) revert InsufficientFunds();

        _mint(msg.sender, Amount);
        uint64 updatedAux = userAux + (Amount << 4);
        _setAux(msg.sender, updatedAux);
        Supply += Amount;
    }


    function PublicMint(uint48 _mintAmount)
        external
        payable
        CallerIsUser
        mintPublic(_mintAmount)
    {
        if (currSalesPhase != 1) revert WrongSalesPhase();
        if (_mintAmount == 0) revert InvalidMintAmount();
        if (Supply + _mintAmount > MAX_SUPPLY) revert MintAmountExceedsSupply();        
        if (msg.value < _mintAmount * PUBLIC_PRICE) revert InsufficientFunds();
        _mint(msg.sender, _mintAmount);
        Supply += _mintAmount;
    }

    // onlyOwner functions

    function devMint(address _to, uint48 _numberOfTokens)
        external 
        onlyOwner 
    {
        if (Supply + _numberOfTokens > MAX_SUPPLY) revert MintAmountExceedsSupply();
        _mint(_to, _numberOfTokens);
        Supply += _numberOfTokens;
    }

    function setMerkleRoot(bytes32 newRoot_) 
        external 
        onlyOwner 
    {
        _merkleRoot = newRoot_;
    }

    function setURI(string calldata _uri) 
        external 
        onlyOwner 
    {
        metadataURI = _uri;
    }

    function demoteSalesPhase(uint8 amount)
        external 
        onlyOwner 
    {
        uint8 resultingPhase = currSalesPhase >> amount;
        if (resultingPhase == 0) revert InvalidSalesPhaseChange();
        currSalesPhase = resultingPhase;
    }

    function promoteSalesPhase(uint8 amount)
        external 
        onlyOwner 
    {
        uint8 resultingPhase = currSalesPhase << amount;
        if (resultingPhase == 0) revert InvalidSalesPhaseChange();
        currSalesPhase = resultingPhase;
    }

    function setPublicMintPrice(uint _mintPrice) 
        external 
        onlyOwner 
    {
        if (_mintPrice < 0.01 ether) revert InvalidMintPriceChange();
        PUBLIC_PRICE = _mintPrice;
    }

    function setWlMintPrice(uint _mintPrice) 
        external 
        onlyOwner 
    {
        if (_mintPrice < 0.01 ether) revert InvalidMintPriceChange();
        ALLOW_LIST_PRICE = _mintPrice;
    }


    function withdraw(uint256 _amount, address _to) 
        external 
        onlyOwner 
    {
        uint256 contractBalance = address(this).balance;
        if (contractBalance < _amount) revert InvalidWithdrawalAmount();

        (bool success,) = payable(_to).call{value: _amount}("");
        if (!success) revert WithdrawalFailed();
    }

    function burn(uint256 _tokenId) 
        external
        onlyOwner 
    {
        _burn(_tokenId, true);
    }

    // public view functions
    function numberMinted(address owner) 
        public 
        view 
        returns (uint256) 
    {
        return _numberMinted(owner);
    }
    // internal functions
    function _baseURI() 
        internal 
        view 
        virtual 
        override 
        returns (string memory) 
    {
        return metadataURI;
    }
}
