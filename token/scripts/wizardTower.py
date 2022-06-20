#!/usr/bin/python3

from brownie import Wizards, Token, WizardTower, accounts

DUMP_ABI = True

def main():
    token = Token.deploy("Test Token", "TST", 18, 1e21, {'from': accounts[0]})
    wizards = Wizards.deploy("Wizards", "WZD", token.address, {'from': accounts[0]})
    wizard_tower = WizardTower.deploy(token.address, wizards.address, {'from': accounts[0]})
    ts = wizards.totalSupply()
    print(f'total supply: {ts}')
    tx = wizards.mint({'from': accounts[0]})
    tx.wait(1)
    ts = wizards.totalSupply()
    print(f'total supply: {ts}')

    if DUMP_ABI:
        import os
        print(f'dumping abi...') # sdf sfd sdfsdf sdf
        dir = os.getcwd()
        path = os.path.join(dir, "abi_dump")
        # print(f'path: {path}')
        abi = str(wizard_tower.abi)
        file_path = os.path.join(path, "wizardTowerABI.json")
        with open(file_path, 'w') as file:
            file.write(abi)

    # return Wizards.deploy("Wizards", "WZD", {'from': accounts[0]})
