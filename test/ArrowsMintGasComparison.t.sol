// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import "../src/Arrows.sol";
import "../src/ArrowsOptimized.sol";

/**
 * @title Arrows Mint Gas Comparison Test
 * @dev Test suite comparing gas usage between original and optimized mint implementations
 */
contract ArrowsMintGasComparisonTest is Test {
    // Contracts under test
    Arrows private _original;
    ArrowsOptimized private _optimized;

    // Test addresses
    address private _user;

    // Test parameters
    uint256 private _mintPrice = 0.001 ether;
    uint8 private _batchSize = 8;
    uint8 private _mintCount = 5;

    // Gas usage tracking
    uint256[] private _originalGasUsage;
    uint256[] private _optimizedGasUsage;
    uint256 private _totalOriginalGas;
    uint256 private _totalOptimizedGas;

    function setUp() public {
        _user = address(0x1);
        vm.deal(_user, 10 ether);

        _original = new Arrows();
        _optimized = new ArrowsOptimized();

        // Set mint limit to 8 for both contracts
        vm.startPrank(address(this));
        _original.updateMintLimit(_batchSize);
        _optimized.updateMintLimit(_batchSize);

        // Ensure mint price is consistent across both contracts
        _original.updateMintPrice(_mintPrice);
        _optimized.updateMintPrice(_mintPrice);

        console.log("Original mintPrice: %d", _original.mintPrice());
        console.log("Optimized mintPrice: %d", _optimized.mintPrice());
        console.log("Original mintLimit: %d", _original.mintLimit());
        console.log("Optimized mintLimit: %d", _optimized.mintLimit());
        vm.stopPrank();

        // Initialize gas arrays
        _originalGasUsage = new uint256[](_mintCount);
        _optimizedGasUsage = new uint256[](_mintCount);
    }

    // Test to compare gas usage of mint function across implementations
    function testMintGasComparison() public {
        uint256 originalEthRequired = _original.mintPrice() * _original.mintLimit();
        uint256 optimizedEthRequired = _optimized.mintPrice() * _optimized.mintLimit();

        console.log("Original ETH required: %d", originalEthRequired);
        console.log("Optimized ETH required: %d", optimizedEthRequired);

        // Use the greater of the two required amounts to ensure we have enough ETH
        uint256 ethToSend = originalEthRequired >= optimizedEthRequired ? originalEthRequired : optimizedEthRequired;
        console.log("Test sending: %d", ethToSend);

        // Perform sequential batch mints and measure gas
        for (uint8 i = 0; i < _mintCount; i++) {
            // Test original contract
            vm.startPrank(_user);
            uint256 gasStart = gasleft();
            _original.mint{value: ethToSend}(_user);
            _originalGasUsage[i] = gasStart - gasleft();
            vm.stopPrank();

            // Test optimized contract
            vm.startPrank(_user);
            gasStart = gasleft();
            _optimized.mint{value: ethToSend}(_user);
            _optimizedGasUsage[i] = gasStart - gasleft();
            vm.stopPrank();

            // Accumulate totals
            _totalOriginalGas += _originalGasUsage[i];
            _totalOptimizedGas += _optimizedGasUsage[i];

            // Log results for this mint
            console.log("=== Mint #%d (Batch Size: %d) ===", i + 1, _batchSize);
            console.log("Original:  %d gas", _originalGasUsage[i]);
            console.log("Optimized: %d gas", _optimizedGasUsage[i]);

            // Safely calculate savings (handle case where optimized uses more gas)
            int256 savings = _originalGasUsage[i] >= _optimizedGasUsage[i]
                ? int256(_originalGasUsage[i] - _optimizedGasUsage[i])
                : -int256(_optimizedGasUsage[i] - _originalGasUsage[i]);

            // Log savings with proper sign
            if (savings >= 0) {
                console.log("Savings:   %d gas", uint256(savings));
            } else {
                console.log("Additional: %d gas", uint256(-savings));
            }

            console.log("Per Token Original:  %d gas", _originalGasUsage[i] / _batchSize);
            console.log("Per Token Optimized: %d gas", _optimizedGasUsage[i] / _batchSize);
            console.log("");
        }

        // Log summary
        console.log("=== SUMMARY ===");
        console.log("Total Gas (Original):  %d gas", _totalOriginalGas);
        console.log("Total Gas (Optimized): %d gas", _totalOptimizedGas);

        // Safely calculate total savings
        int256 totalSavings = _totalOriginalGas >= _totalOptimizedGas
            ? int256(_totalOriginalGas - _totalOptimizedGas)
            : -int256(_totalOptimizedGas - _totalOriginalGas);

        // Log total savings with proper sign
        if (totalSavings >= 0) {
            console.log("Total Savings:         %d gas", uint256(totalSavings));
        } else {
            console.log("Total Additional:      %d gas", uint256(-totalSavings));
        }

        console.log("Average Gas Per Mint (Original):  %d gas", _totalOriginalGas / _mintCount);
        console.log("Average Gas Per Mint (Optimized): %d gas", _totalOptimizedGas / _mintCount);
        console.log("Average Gas Per Token (Original):  %d gas", _totalOriginalGas / (_mintCount * _batchSize));
        console.log("Average Gas Per Token (Optimized): %d gas", _totalOptimizedGas / (_mintCount * _batchSize));

        // Calculate percentage savings (safely)
        int256 percentSavings = 0;
        if (totalSavings > 0 && _totalOriginalGas > 0) {
            percentSavings = int256((uint256(totalSavings) * 100) / _totalOriginalGas);
            console.log("Gas Savings: %d%%", uint256(percentSavings));
        } else if (totalSavings < 0 && _totalOriginalGas > 0) {
            percentSavings = -int256((uint256(-totalSavings) * 100) / _totalOriginalGas);
            console.log("Gas Increase: %d%%", uint256(-percentSavings));
        }

        // Generate report with detailed information
        string memory report = string(
            abi.encodePacked(
                "ARROWS MINT GAS COMPARISON REPORT\n",
                "==================================\n\n",
                "Configuration:\n",
                "- Batch Size: ",
                vm.toString(_batchSize),
                " tokens\n",
                "- Number of Mints: ",
                vm.toString(_mintCount),
                "\n\n",
                "Detailed Results:\n"
            )
        );

        for (uint8 i = 0; i < _mintCount; i++) {
            int256 savings = _originalGasUsage[i] >= _optimizedGasUsage[i]
                ? int256(_originalGasUsage[i] - _optimizedGasUsage[i])
                : -int256(_optimizedGasUsage[i] - _originalGasUsage[i]);

            int256 savingsPercent = 0;
            if (savings > 0 && _originalGasUsage[i] > 0) {
                savingsPercent = int256((uint256(savings) * 100) / _originalGasUsage[i]);
            } else if (savings < 0 && _originalGasUsage[i] > 0) {
                savingsPercent = -int256((uint256(-savings) * 100) / _originalGasUsage[i]);
            }

            string memory savingsStr;
            if (savings >= 0) {
                savingsStr = string(
                    abi.encodePacked(
                        vm.toString(uint256(savings)), " gas (", vm.toString(uint256(savingsPercent)), "%)"
                    )
                );
            } else {
                savingsStr = string(
                    abi.encodePacked(
                        "-", vm.toString(uint256(-savings)), " gas (-", vm.toString(uint256(-savingsPercent)), "%)"
                    )
                );
            }

            report = string(
                abi.encodePacked(
                    report,
                    "Mint #",
                    vm.toString(i + 1),
                    ":\n",
                    "- Original:  ",
                    vm.toString(_originalGasUsage[i]),
                    " gas\n",
                    "- Optimized: ",
                    vm.toString(_optimizedGasUsage[i]),
                    " gas\n",
                    "- Savings:   ",
                    savingsStr,
                    "\n",
                    "- Per Token Original:  ",
                    vm.toString(_originalGasUsage[i] / _batchSize),
                    " gas\n",
                    "- Per Token Optimized: ",
                    vm.toString(_optimizedGasUsage[i] / _batchSize),
                    " gas\n\n"
                )
            );
        }

        string memory totalSavingsStr;
        if (totalSavings >= 0) {
            totalSavingsStr = string(
                abi.encodePacked(
                    vm.toString(uint256(totalSavings)),
                    " gas (",
                    vm.toString(uint256(percentSavings > 0 ? uint256(percentSavings) : 0)),
                    "%)"
                )
            );
        } else {
            totalSavingsStr = string(
                abi.encodePacked(
                    "-", vm.toString(uint256(-totalSavings)), " gas (-", vm.toString(uint256(-percentSavings)), "%)"
                )
            );
        }

        report = string(
            abi.encodePacked(
                report,
                "Summary:\n",
                "- Total Gas (Original):  ",
                vm.toString(_totalOriginalGas),
                " gas\n",
                "- Total Gas (Optimized): ",
                vm.toString(_totalOptimizedGas),
                " gas\n",
                "- Total Savings:         ",
                totalSavingsStr,
                "\n",
                "- Average Gas Per Mint (Original):  ",
                vm.toString(_totalOriginalGas / _mintCount),
                " gas\n",
                "- Average Gas Per Mint (Optimized): ",
                vm.toString(_totalOptimizedGas / _mintCount),
                " gas\n",
                "- Average Gas Per Token (Original):  ",
                vm.toString(_totalOriginalGas / (_mintCount * _batchSize)),
                " gas\n",
                "- Average Gas Per Token (Optimized): ",
                vm.toString(_totalOptimizedGas / (_mintCount * _batchSize)),
                " gas\n\n"
            )
        );

        // Log the full report
        console.log("=== MINT GAS OPTIMIZATION REPORT ===");
        console.log(report);
        console.log("=== END OF REPORT ===");
    }
}
