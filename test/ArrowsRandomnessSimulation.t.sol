// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import "../src/libraries/Utilities.sol";

/**
 * @title Arrows Randomness Simulation Test
 * @dev Test suite that implements public versions of the randomness generation
 *      algorithms from Arrows.sol and ArrowsOptimized.sol to compare their output
 */
contract ArrowsRandomnessSimulationTest is Test {
    // Simulation parameters
    uint32 private constant _SAMPLE_SIZE = 1000;

    // Common seed generation for consistency
    function _generateRandomSeed(uint256 tokenId, address sender) internal view returns (uint256) {
        return
            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, tokenId, sender))) % type(uint128).max;
    }

    // Randomness data structure to track generated values
    struct TokenRandomness {
        uint8 colorBand;
        uint8 gradient;
    }

    // Original Arrows.sol implementation
    function generateOriginalRandomness(uint256 seed) public pure returns (uint8 colorBand, uint8 gradient) {
        // Original implementation from Arrows.sol
        uint256 n = Utilities.random(seed, "band", 120);
        colorBand = n > 80 ? 0 : n > 40 ? 1 : n > 20 ? 2 : n > 10 ? 3 : n > 4 ? 4 : n > 1 ? 5 : 6;

        n = Utilities.random(seed, "gradient", 100);
        gradient = n < 20 ? uint8(1 + (n % 6)) : 0;
    }

    // Current ArrowsOptimized.sol implementation
    function generateCurrentOptimized(uint256 seed) public pure returns (uint8 colorBand, uint8 gradient) {
        // Extract non-contiguous bytes as per updated implementation
        uint8 n1 = uint8(seed & 0xFF); // Byte 0
        uint8 n2 = uint8((seed >> 56) & 0xFF); // Byte 7 (shifted 56 bits)

        // Scale n1 to match original 0-120 range to preserve rarity distribution
        uint8 scaledN1 = uint8((uint256(n1) * 120) / 255);
        colorBand = scaledN1 > 80
            ? 0
            : scaledN1 > 40 ? 1 : scaledN1 > 20 ? 2 : scaledN1 > 10 ? 3 : scaledN1 > 4 ? 4 : scaledN1 > 1 ? 5 : 6;

        // Scale n2 to match original 0-100 range to preserve rarity distribution
        uint8 scaledN2 = uint8((uint256(n2) * 100) / 255);
        gradient = scaledN2 < 20 ? uint8(1 + (scaledN2 % 6)) : 0;
    }

    // Test function to compare distributions
    function testRandomnessDistributions() public view {
        // Initialize counters for tracking distribution
        uint32[7] memory originalBandDistribution;
        uint32[7] memory currentOptBandDistribution;

        uint32[7] memory originalGradientDistribution;
        uint32[7] memory currentOptGradientDistribution;

        // Initialize all array elements to zero
        for (uint8 i = 0; i < 7; i++) {
            originalBandDistribution[i] = 0;
            currentOptBandDistribution[i] = 0;

            originalGradientDistribution[i] = 0;
            currentOptGradientDistribution[i] = 0;
        }

        // Statistics for tracking matches with original
        uint32 currentOptMatchCount = 0;

        // Simulate random seeds
        for (uint32 i = 0; i < _SAMPLE_SIZE; i++) {
            // Generate a random sender address
            address sender = address(uint160(uint256(keccak256(abi.encodePacked(i, "sender")))));

            // Generate seed as done in the contracts
            uint256 seed = _generateRandomSeed(i, sender);

            // Generate randomness using all methods
            (uint8 origBand, uint8 origGradient) = generateOriginalRandomness(seed);
            (uint8 currOptBand, uint8 currOptGradient) = generateCurrentOptimized(seed);

            // Update distributions
            originalBandDistribution[origBand]++;
            currentOptBandDistribution[currOptBand]++;

            originalGradientDistribution[origGradient]++;
            currentOptGradientDistribution[currOptGradient]++;

            // Check matches with original
            bool currOptMatch = (origBand == currOptBand) && (origGradient == currOptGradient);

            if (currOptMatch) currentOptMatchCount++;

            // Add to report (only include first 20 samples to keep it readable)
            if (i < 20) {
                console.log(
                    string(
                        abi.encodePacked(
                            vm.toString(i),
                            " | ",
                            "B:",
                            vm.toString(uint256(origBand)),
                            " G:",
                            vm.toString(uint256(origGradient)),
                            " | ",
                            "B:",
                            vm.toString(uint256(currOptBand)),
                            " G:",
                            vm.toString(uint256(currOptGradient)),
                            " | ",
                            currOptMatch ? "match" : "diff"
                        )
                    )
                );
            }
        }

        // Print distribution analysis
        console.log("\nColor Band Distribution:");
        console.log("Band | Original | Current Opt");
        console.log("-----|----------|-------------");

        for (uint8 i = 0; i < 7; i++) {
            console.log(
                string(
                    abi.encodePacked(
                        "  ",
                        vm.toString(i),
                        " | ",
                        vm.toString((uint256(originalBandDistribution[i]) * 10000) / _SAMPLE_SIZE / 100),
                        ".",
                        vm.toString((uint256(originalBandDistribution[i]) * 10000) / _SAMPLE_SIZE % 100),
                        "% | ",
                        vm.toString((uint256(currentOptBandDistribution[i]) * 10000) / _SAMPLE_SIZE / 100),
                        ".",
                        vm.toString((uint256(currentOptBandDistribution[i]) * 10000) / _SAMPLE_SIZE % 100),
                        "%"
                    )
                )
            );
        }

        console.log("\nGradient Distribution:");
        console.log("Grad | Original | Current Opt");
        console.log("-----|----------|-------------");

        for (uint8 i = 0; i < 7; i++) {
            console.log(
                string(
                    abi.encodePacked(
                        "  ",
                        vm.toString(i),
                        " | ",
                        vm.toString((uint256(originalGradientDistribution[i]) * 10000) / _SAMPLE_SIZE / 100),
                        ".",
                        vm.toString((uint256(originalGradientDistribution[i]) * 10000) / _SAMPLE_SIZE % 100),
                        "% | ",
                        vm.toString((uint256(currentOptGradientDistribution[i]) * 10000) / _SAMPLE_SIZE / 100),
                        ".",
                        vm.toString((uint256(currentOptGradientDistribution[i]) * 10000) / _SAMPLE_SIZE % 100),
                        "%"
                    )
                )
            );
        }

        // Print match summary
        console.log(
            string(
                abi.encodePacked(
                    "\nMatch Rate: ",
                    vm.toString((currentOptMatchCount * 100) / _SAMPLE_SIZE),
                    "% (",
                    vm.toString(currentOptMatchCount),
                    " out of ",
                    vm.toString(_SAMPLE_SIZE),
                    ")"
                )
            )
        );
    }

    // Test to show specific seed examples
    function testRandomSeedExamples() public view {
        console.log("\n=== RANDOM SEED EXAMPLES ===");
        console.log("This test shows examples of specific seed values and their outputs from all algorithms");

        uint256[] memory exampleSeeds = new uint256[](5);
        exampleSeeds[0] = 12345;
        exampleSeeds[1] = 67890;
        exampleSeeds[2] = 1000000;
        exampleSeeds[3] = 0xdeadbeef;
        exampleSeeds[4] = 0xabcdef123456789;

        string memory seedReport = "SEED EXAMPLES\n";
        seedReport = string(abi.encodePacked(seedReport, "=============\n\n"));
        seedReport = string(abi.encodePacked(seedReport, "Seed | Original | Current Opt\n"));
        seedReport = string(abi.encodePacked(seedReport, "-----|----------|-------------\n"));

        for (uint256 i = 0; i < exampleSeeds.length; i++) {
            uint256 seed = exampleSeeds[i];

            // Get outputs from all implementations
            (uint8 origBand, uint8 origGradient) = generateOriginalRandomness(seed);
            (uint8 currOptBand, uint8 currOptGradient) = generateCurrentOptimized(seed);

            // Add to report
            seedReport = string(
                abi.encodePacked(
                    seedReport,
                    vm.toString(seed),
                    " | ",
                    "B:",
                    vm.toString(uint256(origBand)),
                    ",G:",
                    vm.toString(uint256(origGradient)),
                    " | ",
                    "B:",
                    vm.toString(uint256(currOptBand)),
                    ",G:",
                    vm.toString(uint256(currOptGradient)),
                    "\n"
                )
            );
        }

        console.log(seedReport);
    }
}
