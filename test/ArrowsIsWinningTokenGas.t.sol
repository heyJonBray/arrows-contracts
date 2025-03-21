// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Arrows.sol";
import "../src/ArrowsOptimized.sol";

/**
 * @title Arrows IsWinningToken Gas Test
 * @dev Test suite comparing gas usage between original and optimized isWinningToken implementations
 */
contract ArrowsIsWinningTokenGasTest is Test {
    // Contracts under test
    Arrows _original;
    ArrowsOptimized _optimized;

    // Test addresses
    address private _user;

    // Test parameters
    uint256 _mintPrice = 0.001 ether;

    // Setup function to initialize contracts and mint tokens
    function setUp() public {
        _user = address(0x1);
        vm.deal(_user, 10 ether);

        _original = new Arrows();
        _optimized = new ArrowsOptimized();

        // Set mint limit to 1 for both contracts
        vm.startPrank(address(this));
        _original.updateMintLimit(1);
        _optimized.updateMintLimit(1);
        vm.stopPrank();

        // Mint a token with each contract
        vm.startPrank(_user);
        _original.mint{value: _mintPrice}(_user);
        _optimized.mint{value: _mintPrice}(_user);
        vm.stopPrank();
    }

    // Test to compare gas usage of isWinningToken function
    function testIsWinningTokenGasComparison() public {
        emit log("==== isWinningToken Gas Comparison ====");

        // Original contract gas measurement
        uint256 gasStart = gasleft();
        _original.isWinningToken(0);
        uint256 originalGas = gasStart - gasleft();

        // Optimized contract gas measurement
        gasStart = gasleft();
        _optimized.isWinningToken(0);
        uint256 optimizedGas = gasStart - gasleft();

        // Report results
        emit log(string(abi.encodePacked("Original Implementation:  ", vm.toString(originalGas), " gas")));
        emit log(string(abi.encodePacked("Optimized Implementation: ", vm.toString(optimizedGas), " gas")));

        int256 diff = int256(originalGas) - int256(optimizedGas);
        if (diff > 0) {
            uint256 savingsPercent = uint256(diff) * 100 / originalGas;
            emit log(
                string(
                    abi.encodePacked(
                        "Gas Savings: ", vm.toString(uint256(diff)), " gas (", vm.toString(savingsPercent), "%)"
                    )
                )
            );
        } else if (diff < 0) {
            uint256 increasePct = uint256(-diff) * 100 / originalGas;
            emit log(
                string(
                    abi.encodePacked(
                        "Gas Increase: ", vm.toString(uint256(-diff)), " gas (", vm.toString(increasePct), "%)"
                    )
                )
            );
        } else {
            emit log("No gas difference between implementations");
        }
    }
}
