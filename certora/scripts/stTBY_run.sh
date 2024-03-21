#/bin/bash
cp -f src/token/StTBY.sol certora/munged/StTBYMunged.sol
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' 's/uint256\ private\ immutable\ _scalingFactor/uint256\ public\ immutable\ _scalingFactor/g' certora/munged/StTBYMunged.sol
    sed -i '' 's/uint256\ private\ constant\ MINT_REWARD_CUTOFF/uint256\ public\ constant\ MINT_REWARD_CUTOFF/g' certora/munged/StTBYMunged.sol
    sed -i '' 's/\"..\//\"src\//g' certora/munged/StTBYMunged.sol
    sed -i '' 's/\".\//\"src\/token\//g' certora/munged/StTBYMunged.sol
else
    sed -i 's/uint256\ private\ immutable\ _scalingFactor/uint256\ public\ immutable\ _scalingFactor/g' certora/munged/StTBYMunged.sol
    sed -i 's/uint256\ private\ constant\ MINT_REWARD_CUTOFF/uint256\ public\ constant\ MINT_REWARD_CUTOFF/g' certora/munged/StTBYMunged.sol
    sed -i 's/\"..\//\"src\//g' certora/munged/StTBYMunged.sol
    sed -i 's/\".\//\"src\/token\//g' certora/munged/StTBYMunged.sol
fi
certoraRun certora/confs/StTBY.conf $1