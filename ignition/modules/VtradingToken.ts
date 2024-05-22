import {buildModule} from "@nomicfoundation/hardhat-ignition/modules";



const VtradingTokenModel = buildModule("VtradingToken", (m) => {

    const initialOwner = m.getParameter("initialOwner", "");

    const vtradingToken = m.contract("VtradingToken", [initialOwner]);

    return {vtradingToken};
});


export default VtradingTokenModel;