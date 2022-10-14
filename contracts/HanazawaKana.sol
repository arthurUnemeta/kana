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
error MintAmountFreeExceedsSupply();
error WithdrawalFailed();
error WrongSalesPhase();
error InvalidMerkleProof();
error MintAmountExceedsUserAllowance();

contract HanazawaKanaNFT is ERC721A, Ownable {
    event MintedCounters(
        uint48 indexed amount,
        uint48 indexed userConfig
    );

    event SalesPhaseChanged(
        uint8 indexed newPhase
    );
    uint48 public constant MAX_SUPPLY = 6666;
    uint48 public constant MAX_FREE_SUPPLY = 2000;
    uint256 public  PUBLIC_PRICE = 0.1 ether;
    uint256 public  ALLOW_LIST_PRICE = 0.08 ether;
    uint48 public Supply = 0;
    mapping(address => bool) public FreelistClaimed;
    uint48 public constant SECTION_BITMASK = 15;
    uint48 public constant DISTRICT_BITMASK = 4095;
    uint8 public PUBLIC_SUPPLY =3;
    uint8 public SALES_PHASE = 8;
    uint8 public PUBLIC_SAlES =1;
    uint8 public WL_SALES =2;
    uint8 public FREE_SALES =4;
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
        uint48 userSalesPhase = (_inputConfig >> 24) & SECTION_BITMASK;
        uint48 Amount = _inputConfig & DISTRICT_BITMASK;
        if (Amount == 0) revert InvalidMintAmount();
        if (Supply+Amount > MAX_FREE_SUPPLY) revert MintAmountFreeExceedsSupply();

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender,amountAllowed,userSalesPhase));
        if (!MerkleProof.verifyCalldata(_proof, _merkleRoot, leaf)) revert InvalidMerkleProof();
        if (userSalesPhase != SALES_PHASE) revert WrongSalesPhase();
        if (SALES_PHASE != FREE_SALES) revert WrongSalesPhase();
 
        uint64 userAux = _getAux(msg.sender);
        uint64 allowlistMinted = (userAux >> 8) & SECTION_BITMASK;
        if (allowlistMinted + Amount > amountAllowed) revert MintAmountExceedsUserAllowance();
        

        _mint(msg.sender, Amount);
        uint64 updatedAux = userAux + (Amount << 8);
        emit MintedCounters(Amount, _inputConfig);
        _setAux(msg.sender, updatedAux);
        Supply += Amount;
    }

    function WhitelistMint(bytes32[] calldata _proof, uint48 _inputConfig)
        external
        payable
        CallerIsUser
    {
        uint48 amountAllowed = (_inputConfig >> 16) & SECTION_BITMASK;
        uint48 userSalesPhase = (_inputConfig >> 24) & SECTION_BITMASK;
        uint48 Amount = _inputConfig & DISTRICT_BITMASK;
        if (Amount == 0) revert InvalidMintAmount();
        if (Supply+Amount > MAX_SUPPLY) revert MintAmountExceedsSupply();
      
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, amountAllowed,userSalesPhase));
        if (!MerkleProof.verifyCalldata(_proof, _merkleRoot, leaf)) revert InvalidMerkleProof();
        if (userSalesPhase != SALES_PHASE) revert WrongSalesPhase();
        if (SALES_PHASE != WL_SALES) revert WrongSalesPhase();

        uint64 userAux = _getAux(msg.sender);
        uint64 allowlistMinted = (userAux >> 4) & SECTION_BITMASK;
        if (allowlistMinted + Amount > amountAllowed) revert MintAmountExceedsUserAllowance();
        
        if (msg.value < Amount * ALLOW_LIST_PRICE) revert InsufficientFunds();

        _mint(msg.sender, Amount);
        uint64 updatedAux = userAux + (Amount << 4);
        emit MintedCounters(Amount, _inputConfig);
        _setAux(msg.sender, updatedAux);
        Supply += Amount;
    }


    function PublicMint(uint48 _mintAmount)
        external
        payable
        CallerIsUser
        mintPublic(_mintAmount)
    {
        if (SALES_PHASE != PUBLIC_SAlES) revert WrongSalesPhase();
        if (_mintAmount == 0) revert InvalidMintAmount();

        uint64 userAux = _getAux(msg.sender);
        uint64 allowlistMinted = (userAux >> 12) & SECTION_BITMASK;
        if (allowlistMinted + _mintAmount > PUBLIC_SUPPLY) revert MintAmountExceedsUserAllowance();
        if (msg.value < _mintAmount * PUBLIC_PRICE) revert InsufficientFunds();

        _mint(msg.sender, _mintAmount);
        uint64 updatedAux = userAux + (_mintAmount << 12);
        emit MintedCounters(_mintAmount, 0);
        _setAux(msg.sender, updatedAux);
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
        uint8 resultingPhase = SALES_PHASE >> amount;
        if (resultingPhase == 0) revert InvalidSalesPhaseChange();
        SALES_PHASE = resultingPhase;
        emit SalesPhaseChanged(SALES_PHASE);
    }

    function promoteSalesPhase(uint8 amount)
        external 
        onlyOwner 
    {
        uint8 resultingPhase = SALES_PHASE << amount;
        if (resultingPhase == 0) revert InvalidSalesPhaseChange();
        SALES_PHASE = resultingPhase;
        emit SalesPhaseChanged(SALES_PHASE);
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

    function numberMinted(address owner) 
        public 
        view 
        returns (uint256) 
    {
        return _numberMinted(owner);
    }
    function numberMintedWhiteList(address owner) 
        public 
        view 
        returns (uint64) 
    {
        return (_getAux(owner) >> 4) & SECTION_BITMASK;
    }
    function numberMintedFree(address owner) 
        public 
        view 
        returns (uint64) 
    {
        return (_getAux(owner) >> 8) & SECTION_BITMASK;
    }
    function numberMintedPublic(address owner) 
        public 
        view 
        returns (uint64) 
    {
        return (_getAux(owner) >> 12) & SECTION_BITMASK;
    }
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
