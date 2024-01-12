pragma solidity 0.8.19;

import {IStrategyHelper} from "../interfaces/IStrategyHelper.sol";

library PairMath {
    function add(
        IStrategyHelper.PairAssets memory a,
        IStrategyHelper.PairAssets memory b
    ) internal pure returns (IStrategyHelper.PairAssets memory) {
        return IStrategyHelper.PairAssets(a.asset + b.asset, a.counterAsset + b.counterAsset);
    }

    function sub(
        IStrategyHelper.PairAssets memory a,
        IStrategyHelper.PairAssets memory b
    ) internal pure returns (IStrategyHelper.PairAssets memory) {
        require(a.asset >= b.asset && a.counterAsset >= b.counterAsset, "PairMath: subtraction overflow");
        return IStrategyHelper.PairAssets(a.asset - b.asset, a.counterAsset - b.counterAsset);
    }
}
