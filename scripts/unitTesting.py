import time
from brownie import accounts, config
from brownie import BaseContract, DAI

accountA = accounts.add(config['wallets']['from_key'][0])
accountB = accounts.add(config['wallets']['from_key'][1])
print(accountA, accountB)

# brownie run scripts/unitTesting.py --network development

def main():
    contract_DAI = DAI.deploy({"from":accountA})
    base_contract = BaseContract.deploy(contract_DAI, accountB, {"from":accountA})
    base_contract.startVerification()